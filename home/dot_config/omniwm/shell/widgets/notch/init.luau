-- Notch: a Dynamic Island for OmniWM over the MacBook notch, modelled on Notchy.
-- Rest: invisible inside the notch; only brief flashes (workspace, volume, brightness,
-- power, shelf) break out, and an agent waiting for you drops "Claude in session-0 is
-- asking for your help" (crew component, read-only). Hover: the live activities (TUIOS agents as pixel critters, the pomodoro
-- with a critter riding its countdown, music, mic/camera dots), a one-line peek and the
-- apps in each workspace (spaces component). Click: a black panel with Notchy's
-- header (tabs in a capsule, round quick actions, a pin to keep it open) and tabs Home
-- (now + timer | system), Agents, Music (seek, shuffle/repeat, volume, synced
-- lyrics), Timer and Shelf. The pomodoro starts on its own when you hand an agent work,
-- and stops after ten minutes with no agent working. Scroll on the pill to
-- change workspace; drag files onto it for the shelf.
-- agents.sh pushes `omniwmctl shell trigger notch update "<working> <state>"` and
-- `... notch agents '<json>'`.

interval = 1

local SHAPE = { response = 0.36, bounce = 0.16 }
local CONTENT = { response = 0.26, bounce = 0.04 }
local APPEAR = { opacity = 0, scale = 0.8, animate = CONTENT }
local EXIT = { opacity = 0, scale = 0.8, animate = { response = 0.16, bounce = 0 } }
local FADE_IN = { opacity = 0, dy = -8, animate = CONTENT }
local FADE_OUT = { opacity = 0, dy = -6, animate = 0.12 }

local BLACK = "#000000"
local TEXT = "#F5F5F7"
local DIM = "#FFFFFF99"
local FAINT = "#FFFFFF40"
local TRACK = "#FFFFFF2E"
local HOVER = "#FFFFFF1A"
local CARD = "#FFFFFF12"
local CARD_LINE = "#FFFFFF14"
local YELLOW = "#FFD60A"
local RED = "#FF453A"
local ORANGE = "#FF9F0A"
local GREEN = "#30D158"
local TOMATO = "#FF6B5A"
local PURPLE = "#BF5AF2"
local CYAN = "#64D2FF"

local CREW = "crew" -- component instance id in shell.toml
local SPACES = "spaces" -- the apps in each workspace, shown on hover
local FLASH_SECONDS = 1.6
local SHOULDER = 6 -- concave flare where the island meets the top edge of the screen
local PAD = 10 -- wing padding
local PANEL_WIDTH = 700 -- as wide as Notchy's panel
local PEEK_WIDTH = 460 -- the hover, with the workspace strip
local HOME_H = 240
local OFFICE_H = 226 -- the Agents tab: the crew component's pixel office (170) and its details strip (56)
local MUSIC_COVER, MUSIC_H = 150, 164
local ALERT_WIDTH = 440
local HELP_H = 56
local INSET = 18 -- panel side margin
local TABS_H = 32
local PEEK_H = 40
local STRIP_H = 36
local ROW = 24
local COVER = 40
local TILE_W, TILE_H = 56, 64
local PRECISE_STEP = 30 -- trackpad points per workspace step
local SHELF_LIMIT = 24
local DROP_KINDS = { "file", "url", "text", "image" }
local EQUALIZER = omniwm.asset("@self/equalizer.metal")
local AVATAR = omniwm.asset("@self/avatar.metal")

local FOCUS, SHORT_BREAK, LONG_BREAK = 25 * 60, 5 * 60, 15 * 60
local DURATIONS = { focus = FOCUS, short = SHORT_BREAK, long = LONG_BREAK }
local PHASES = { focus = "Focus", short = "Break", long = "Long break", idle = "Ready" }
local QUIET_STOP = 10 * 60 -- stop the focus after this long with no agent working
local MANUAL_COOLDOWN = 5 * 60 -- no automatic start this soon after you stopped it

local TABS = {
    { id = "home", symbol = "house.fill", title = "Home" },
    { id = "agents", symbol = "person.2.fill", title = "Agents" },
    { id = "music", symbol = "music.note", title = "Music" },
    { id = "timer", symbol = "timer", title = "Timer" },
    { id = "shelf", symbol = "tray.full.fill", title = "Shelf" },
}

local function measure(ctx, text: string, size: number, weight: Weight?): number
    local width = ctx.format.measure(text, { size = size, weight = weight })
    return math.ceil(width)
end

local function text(value): string
    return if type(value) == "string" then value else ""
end

local function bump(state)
    state.revision = (state.revision or 0) + 1
end

local function remember(state, key: string, value)
    local previous = state[key]
    if previous ~= value then
        state[key] = value
    end
    return previous
end

local function focusedWorkspace(workspaces: { Workspace }): Workspace?
    for _, workspace in workspaces do
        if workspace.focused then
            return workspace
        end
    end
    return nil
end

local function fraction(value: number?): number?
    if not value then
        return nil
    end
    return math.clamp(if value > 1 then value / 100 else value, 0, 1)
end

local function mmss(seconds: number): string
    local total = math.max(0, math.ceil(seconds))
    return string.format("%02d:%02d", total // 60, total % 60)
end

-- Agents ------------------------------------------------------------------------------

local MOODS = { working = 0, needs_input = 1, errored = 2 }

-- The agents agents.sh pushed.
local function agentList(state)
    local list = {}
    if type(state.crew) == "table" then
        for _, agent in state.crew do
            if type(agent) == "table" and type(agent.i) == "string" and type(agent.s) == "string" then
                list[#list + 1] = agent
            end
        end
    end
    return list
end

-- What the root needs about the agents: counts, and the one waiting for you. `prompt`
-- names that wait (pane and since when), so Later hides it until another one starts.
local function crewInfo(ctx)
    local mounted = false
    for _, component in ctx.data.components or {} do
        if component.id == CREW and component.enabled then
            mounted = true
        end
    end
    local list = agentList(ctx.state)
    local info = { mounted = mounted, busy = 0, working = 0, total = #list, list = list, aggregate = #list == 0 }
    for _, agent in list do
        if MOODS[agent.s] ~= nil or (agent.s == "done" and agent.u == true) then
            info.busy += 1
        end
        if agent.s == "working" then
            info.working += 1
            info.doing = info.doing or text(agent.n)
        end
        if agent.s == "needs_input" and not info.prompt then
            info.prompt = agent.i .. ":" .. tostring(agent.t)
            info.who = if text(agent.n) ~= "" then agent.n else "An agent"
        end
    end
    if #list == 0 then
        local working = string.match(ctx.state.agents or "", "^(%d+) ")
        info.working = tonumber(working) or 0
    end
    return info
end

local function crewProps(info)
    return { agents = info.list }
end

local function troupeWidth(ctx, busy: number): number
    local shown = math.min(busy, 3)
    local width = shown * 20 + math.max(0, shown - 1) * 2
    if busy > 3 then
        width += 2 + measure(ctx, "+" .. tostring(busy - 3), 11, "semibold")
    end
    return width
end

local function troupe(ctx, info)
    local width = troupeWidth(ctx, info.busy)
    return ui.component{ key = "troupe", id = CREW, view = "troupe", w = width, h = 15, props = crewProps(info) },
        width
end

-- Pomodoro ----------------------------------------------------------------------------

local function pomodoro(state)
    if state.pomo then
        return state.pomo
    end
    local status = omniwm.store.status.state
    local fresh = { phase = "idle", count = 0, auto = true }
    if status == "pending" then
        return fresh
    end
    local saved = if status == "ready" then omniwm.store.get("pomodoro") else nil
    if type(saved) == "table" and DURATIONS[saved.phase] or (type(saved) == "table" and saved.phase == "idle") then
        fresh = { phase = saved.phase, count = tonumber(saved.count) or 0, auto = saved.auto ~= false,
            endsAt = tonumber(saved.endsAt), left = tonumber(saved.left), paused = saved.paused == true,
            stoppedAt = tonumber(saved.stoppedAt), day = saved.day, today = tonumber(saved.today) }
    end
    state.pomo = fresh
    return fresh
end

local function savePomodoro(state)
    if omniwm.store.status.state == "ready" then
        omniwm.store.set("pomodoro", state.pomo)
    end
    bump(state)
end

local function remaining(pomo, now: number): number
    if pomo.phase == "idle" then
        return FOCUS
    end
    if pomo.paused then
        return pomo.left or DURATIONS[pomo.phase]
    end
    return math.max(0, (pomo.endsAt or now) - now)
end

local function startPhase(state, phase: string, now: number)
    local pomo = pomodoro(state)
    pomo.phase = phase
    pomo.endsAt = now + DURATIONS[phase]
    pomo.left = nil
    pomo.paused = false
    savePomodoro(state)
end

local function stopPomodoro(state, now: number, manual: boolean)
    local pomo = pomodoro(state)
    pomo.phase = "idle"
    pomo.endsAt, pomo.left, pomo.paused = nil, nil, false
    pomo.stoppedAt = if manual then now else pomo.stoppedAt
    savePomodoro(state)
end

local function togglePomodoro(state, now: number)
    local pomo = pomodoro(state)
    if pomo.phase == "idle" then
        startPhase(state, "focus", now)
    elseif pomo.paused then
        pomo.endsAt = now + (pomo.left or DURATIONS[pomo.phase])
        pomo.left, pomo.paused = nil, false
        savePomodoro(state)
    else
        pomo.left = remaining(pomo, now)
        pomo.paused = true
        savePomodoro(state)
    end
end

local function advance(state, now: number, working: number)
    local pomo = pomodoro(state)
    if pomo.phase == "focus" then
        pomo.count = (pomo.count or 0) + 1
        startPhase(state, if pomo.count % 4 == 0 then "long" else "short", now)
    elseif pomo.auto and working > 0 then
        startPhase(state, "focus", now)
    else
        stopPomodoro(state, now, false)
    end
end

-- Activities --------------------------------------------------------------------------

local function flash(state, kind: string)
    if state.flashTimer then
        state.flashTimer:cancel()
        state.flashTimer = nil
    end
    local timer = omniwm.after(if kind == "pomodoro" then 3 else FLASH_SECONDS, function()
        state.flashTimer = nil
        state.flash = nil
    end)
    if timer then
        state.flashTimer = timer
        state.flash = kind
    end
end

-- Runs the pomodoro clock and its automation: start when an agent picks up work, stop
-- after a quiet stretch.
local function tick(ctx, working: number)
    local state = ctx.state
    local pomo = pomodoro(state)
    local now = ctx.data.seconds
    if pomo.phase ~= "idle" and not pomo.paused and pomo.endsAt and now >= pomo.endsAt then
        if pomo.phase == "focus" then
            local day = ctx.format.date(now, "yyyy-MM-dd")
            pomo.today = (if pomo.day == day then pomo.today or 0 else 0) + 1
            pomo.day = day
        end
        advance(state, now, working)
        flash(state, "pomodoro")
    end
    local before = remember(state, "lastWorking", working)
    if not pomo.auto then
        return
    end
    if pomo.phase == "idle" and before == 0 and working > 0 and now - (pomo.stoppedAt or 0) > MANUAL_COOLDOWN then
        startPhase(state, "focus", now)
        flash(state, "pomodoro")
    end
    if working > 0 then
        remember(state, "quietSince", nil)
    elseif pomo.phase == "focus" and not pomo.paused then
        if not state.quietSince then
            state.quietSince = now
        elseif now - state.quietSince >= QUIET_STOP then
            stopPomodoro(state, now, false)
            state.quietSince = nil
            flash(state, "pomodoro")
        end
    end
end

-- Flashes what changed since the last render; the first render only takes note.
local function observe(ctx, workspaces: { Workspace })
    local state, data = ctx.state, ctx.data
    local workspace = focusedWorkspace(workspaces)
    local brightness = data.brightness
    local seen = state.seen == true
    local lastWorkspace = remember(state, "lastWorkspace", workspace and workspace.id or nil)
    local lastVolume = remember(state, "lastVolume", data.volume)
    local lastMuted = remember(state, "lastMuted", data.muted == true)
    local lastBrightness = remember(state, "lastBrightness",
        if brightness and brightness.available then brightness.value else nil)
    local lastBattery = remember(state, "lastBattery", data.battery)
    local lastCharging = remember(state, "lastCharging", data.charging == true)
    if not seen then
        state.seen = true
        return
    end
    local charging = data.charging == true
    if workspace and lastWorkspace and workspace.id ~= lastWorkspace then
        flash(state, "workspace")
    elseif data.volume and lastVolume and (data.volume ~= lastVolume or (data.muted == true) ~= lastMuted) then
        flash(state, "volume")
    elseif brightness and brightness.available and lastBrightness
        and math.abs(brightness.value - lastBrightness) > 0.001 then
        flash(state, "brightness")
    elseif data.battery and lastBattery and charging ~= lastCharging then
        flash(state, "power")
    elseif data.battery and lastBattery and not charging
        and ((lastBattery > 20 and data.battery <= 20) or (lastBattery > 10 and data.battery <= 10)) then
        flash(state, "power")
    end
end

local function dots(workspaces: { Workspace })
    local row = { key = "dots", gap = 4, h = 6 }
    local width = 0
    for _, workspace in workspaces do
        local w = if workspace.focused then 14 else 6
        width += w + (if width > 0 then 4 else 0)
        row[#row + 1] = ui.box{ key = "dot-" .. workspace.id, w = w, h = 6, radius = 3, animate = CONTENT,
            fill = if workspace.focused then TEXT elseif workspace.windows > 0 then DIM else FAINT }
    end
    row.w = width
    return ui.row(row), width
end

local function meter(value: number)
    local width = 44
    return ui.stack{ key = "meter", w = width, h = 4, radius = 2, fill = TRACK,
        ui.box{ key = "level", w = math.max(4, width * value), h = 4, radius = 2, fill = TEXT,
            align = "leading", animate = CONTENT } }, width
end

local function volumeSymbol(volume: number, muted: boolean): string
    if muted or volume == 0 then
        return "speaker.slash.fill"
    end
    return if volume < 34 then "speaker.wave.1.fill" elseif volume < 67 then "speaker.wave.2.fill"
        else "speaker.wave.3.fill"
end

local function batterySymbol(level: number, charging: boolean): string
    if charging then
        return "battery.100.bolt"
    end
    return if level > 87 then "battery.100" elseif level > 62 then "battery.75" elseif level > 37 then "battery.50"
        elseif level > 12 then "battery.25" else "battery.0"
end

local function glyph(key: string, symbol: string, color: string?)
    return ui.symbol{ key = key, name = symbol, size = 13, weight = "semibold", color = color or TEXT, w = 18, h = 18 }, 18
end

local function label(ctx, key: string, value: string, color: string?)
    return ui.text{ key = key, text = value, size = 12, weight = "semibold", color = color or TEXT },
        measure(ctx, value, 12, "semibold")
end

local function phaseColor(pomo): string
    return if pomo.paused then DIM elseif pomo.phase == "focus" then TOMATO else GREEN
end

-- A flash: the left and right wing contents with their widths, or nil.
local function flashed(ctx, workspaces: { Workspace })
    local state, data = ctx.state, ctx.data
    local kind = state.flash
    if kind == "workspace" then
        local workspace = focusedWorkspace(workspaces)
        if workspace then
            local left, leftWidth = label(ctx, "workspace", workspace.name)
            local right, rightWidth = dots(workspaces)
            return left, leftWidth, right, rightWidth
        end
    elseif kind == "volume" and data.volume then
        local muted = data.muted == true
        local left, leftWidth = glyph("volume", volumeSymbol(data.volume, muted))
        local right, rightWidth = meter(if muted then 0 else data.volume / 100)
        return left, leftWidth, right, rightWidth
    elseif kind == "brightness" and data.brightness then
        local level = fraction(data.brightness.value) or 0
        local left, leftWidth = glyph("brightness", if level < 0.4 then "sun.min.fill" else "sun.max.fill")
        local right, rightWidth = meter(level)
        return left, leftWidth, right, rightWidth
    elseif kind == "power" and data.battery then
        local charging = data.charging == true
        local color = if charging then GREEN elseif data.battery <= 20 then RED else TEXT
        local left, leftWidth = glyph("power", if charging then "bolt.fill" else batterySymbol(data.battery, false), color)
        local right, rightWidth = label(ctx, "percent", tostring(data.battery) .. "%", color)
        return left, leftWidth, right, rightWidth
    elseif kind == "shelf" and state.shelf then
        local left, leftWidth = glyph("shelf", "tray.full.fill")
        local right, rightWidth = label(ctx, "count", tostring(#state.shelf.items))
        return left, leftWidth, right, rightWidth
    elseif kind == "pomodoro" then
        local pomo = pomodoro(state)
        local color = if pomo.phase == "idle" then DIM else phaseColor(pomo)
        local left, leftWidth = glyph("pomodoro", if pomo.phase == "idle" then "stop.fill" else "timer", color)
        local value = if pomo.phase == "idle" then "Pomodoro stopped"
            else PHASES[pomo.phase] .. " " .. mmss(remaining(pomo, data.seconds))
        local right, rightWidth = label(ctx, "phase", value, color)
        return left, leftWidth, right, rightWidth
    end
    return nil
end

-- The critter rides a rail as the countdown runs, then the time.
local function timerChip(ctx, pomo, now: number)
    local total = DURATIONS[pomo.phase] or FOCUS
    local progress = math.clamp(1 - remaining(pomo, now) / total, 0, 1)
    local color = phaseColor(pomo)
    local rail = 30
    local time = mmss(remaining(pomo, now))
    local timeWidth = measure(ctx, "00:00", 12, "semibold")
    return ui.row{ key = "timer", gap = 6, h = 16,
        ui.stack{ key = "rail", w = rail, h = 14,
            ui.box{ key = "track", w = rail, h = 2, radius = 1, fill = TRACK, align = "bottom" },
            ui.box{ key = "done", w = math.max(2, rail * progress), h = 2, radius = 1, fill = color,
                align = "bottomLeading", animate = CONTENT },
            ui.shader{ key = "rider", source = AVATAR, w = 12, h = 9, fps = 12, align = "bottomLeading",
                dx = progress * (rail - 12), dy = -2, animate = CONTENT,
                values = { if pomo.phase == "focus" and not pomo.paused then 0 else 3, 0.7, 1 } } },
        ui.text{ key = "time", text = time, size = 12, weight = "semibold", color = color, reserve = "00:00" } },
        rail + 6 + timeWidth
end

local function marks(ctx, info)
    local list = {}
    local _, state = string.match(ctx.state.agents or "", "^(%d+) (%S+)$")
    if info.aggregate and state == "needs_input" then
        list[#list + 1] = { key = "agent", color = YELLOW, help = "An agent needs you" }
    elseif info.aggregate and state == "errored" then
        list[#list + 1] = { key = "agent", color = RED, help = "An agent errored" }
    end
    local privacy = ctx.data.privacy
    if privacy and privacy.microphone then
        list[#list + 1] = { key = "microphone", color = ORANGE, help = "Microphone in use" }
    end
    if privacy and privacy.camera then
        list[#list + 1] = { key = "camera", color = GREEN, help = "Camera in use" }
    end
    return list
end

-- Shelf -------------------------------------------------------------------------------

local function shelfSave(state)
    local shelf = state.shelf
    if not shelf or not shelf.persistent then
        return
    end
    local saved = {}
    for _, item in shelf.items do
        if item.token and not item.failed then
            saved[#saved + 1] = { name = item.name, token = item.token }
        end
    end
    local ok, err = omniwm.store.set("shelf", saved)
    shelf.error = if ok then nil else tostring(err)
end

local function shelfLoad(state)
    local status = omniwm.store.status.state
    if status == "pending" then
        return
    end
    local shelf = { items = {}, next = 0, persistent = status == "ready" }
    state.shelf = shelf
    local saved = if shelf.persistent then omniwm.store.get("shelf") else nil
    if type(saved) ~= "table" then
        return
    end
    for _, entry in saved do
        if #shelf.items < SHELF_LIMIT and type(entry) == "table" and type(entry.token) == "string"
            and type(entry.name) == "string" then
            local resource = omniwm.resources.restore(entry.token)
            if resource then
                shelf.next += 1
                shelf.items[#shelf.items + 1] = { id = shelf.next, name = entry.name, token = entry.token,
                    resource = resource }
            end
        end
    end
end

-- Persists one new item at a time, so a restart keeps the shelf.
local function shelfPersist(state)
    local shelf = state.shelf
    if not shelf or shelf.busy then
        return
    end
    for _, item in shelf.items do
        if not item.token and not item.failed then
            local token, err = omniwm.resources.persist(item.resource, function(result)
                shelf.busy = false
                if not result.ok then
                    item.failed = tostring(result.error)
                end
                shelfSave(state)
                bump(state)
                shelfPersist(state)
            end)
            if token then
                item.token = token
                shelf.busy = true
                shelfSave(state)
                return
            end
            item.failed = tostring(err)
        end
    end
    shelfSave(state)
end

local function shelfAdd(state, resources: { Resource })
    local shelf = state.shelf
    if not shelf then
        return
    end
    local known = {}
    for _, item in shelf.items do
        known[item.resource.id] = true
    end
    for _, resource in resources do
        if not known[resource.id] and #shelf.items < SHELF_LIMIT then
            shelf.next += 1
            shelf.items[#shelf.items + 1] = { id = shelf.next, name = resource.name, resource = resource }
            known[resource.id] = true
        end
    end
    bump(state)
    shelfPersist(state)
end

local function shelfRemove(state, id: number)
    local shelf = state.shelf
    for index, item in shelf.items do
        if item.id == id then
            table.remove(shelf.items, index)
            break
        end
    end
    shelfSave(state)
    bump(state)
end

local function shelfClear(ctx)
    ctx.state.shelf.items = {}
    shelfSave(ctx.state)
    bump(ctx.state)
end

local function ready(item): boolean
    return item.resource ~= nil and item.resource.state == "ready"
end

local function shelfOpen(item)
    if not ready(item) then
        return
    end
    if item.resource.kind == "text" then
        omniwm.clipboard.copy(item.resource)
    else
        omniwm.open(item.resource)
    end
end

local function airdrop(ctx)
    local resources = {}
    for _, item in ctx.state.shelf.items do
        if ready(item) then
            resources[#resources + 1] = item.resource
        end
    end
    if #resources > 0 then
        omniwm.share(resources, "shelf-airdrop", "airdrop")
    end
end

-- Panel pieces ------------------------------------------------------------------------

local function button(key: string, symbol: string, action, size: number, help: string?, diameter: number?)
    local d = diameter or 28
    return ui.stack{ key = key, w = d, h = d, radius = d / 2, hover = HOVER, pressScale = 0.9,
        onClick = action, help = help,
        ui.symbol{ name = symbol, size = size, color = TEXT } }
end

local function progress(ctx, media: Media): number?
    local duration, elapsed = media.duration, media.elapsed
    if not duration or duration <= 0 or not elapsed then
        return nil
    end
    if media.playing then
        elapsed += math.max(0, ctx.data.seconds - media.sampledAt) * media.rate
    end
    return math.clamp(elapsed / duration, 0, 1)
end

local function cover(media: Media, size: number, radius: number)
    return if media.artwork then ui.image{ image = media.artwork, w = size, h = size, radius = radius }
        else ui.stack{ w = size, h = size, radius = radius, fill = "#FFFFFF14",
            ui.symbol{ name = "music.note", size = size * 0.4, color = DIM } }
end

local function bar(key: string, width: number, value: number, color: string?)
    return ui.stack{ key = key, w = width, h = 3, radius = 1.5, fill = TRACK,
        ui.box{ key = "elapsed", w = math.max(3, width * math.clamp(value, 0, 1)), h = 3, radius = 1.5,
            fill = color or "#FFFFFFCC",
            align = "leading" } }
end

local function openTab(tab: string)
    return function(ctx)
        ctx.state.tab = tab
        ctx.state.open = true
    end
end

-- Notchy's header: the tabs in one capsule (the current one with its name), with counts.
local function tabs(ctx, current: string, info)
    local row = { key = "tabs", gap = 2, h = TABS_H, pad = 2, radius = TABS_H / 2, fill = "#FFFFFF0F" }
    local shelf = ctx.state.shelf
    local counts = { shelf = if shelf then #shelf.items else 0 }
    local h = TABS_H - 4
    for _, tab in TABS do
        local selected = tab.id == current
        local w = if selected then 28 + measure(ctx, tab.title, 13, "semibold") else 30
        local content = { gap = 6,
            ui.symbol{ name = tab.symbol, size = 13, color = if selected then TEXT else DIM } }
        if selected then
            content[#content + 1] = ui.text{ text = tab.title, size = 13, weight = "semibold", color = TEXT }
        end
        local item = { key = "tab-" .. tab.id, w = w, h = h, radius = h / 2, animate = CONTENT,
            fill = if selected then "#FFFFFF24" else nil, hover = if selected then nil else HOVER,
            onClick = openTab(tab.id), help = tab.title, ui.row(content) }
        local count = counts[tab.id] or 0
        if tab.id == "agents" and info.prompt then
            item[#item + 1] = ui.box{ key = "badge", w = 6, h = 6, radius = 3, fill = YELLOW, align = "topTrailing",
                dx = -5, dy = 4 }
        elseif count > 0 and not selected then
            item[#item + 1] = ui.text{ key = "count", text = tostring(math.min(count, 99)), size = 9,
                weight = "semibold", color = TEXT, align = "bottomTrailing", dx = -3, dy = -1 }
        end
        row[#row + 1] = ui.stack(item)
    end
    return ui.row(row)
end

local function round(key: string, symbol: string, action, help: string, active: boolean?)
    return ui.stack{ key = key, w = 30, h = 30, radius = 15, fill = if active then "#FFFFFF33" else "#FFFFFF14",
        hover = "#FFFFFF2E", pressScale = 0.9, onClick = action, help = help,
        ui.symbol{ name = symbol, size = 13, color = TEXT } }
end

-- The round buttons on the header's right, as Notchy's quick actions.
local function quick(ctx, pomo)
    local muted = ctx.data.muted == true
    local running = pomo.phase ~= "idle" and not pomo.paused
    local pinned = ctx.state.pinned == true
    return ui.row{ key = "quick", gap = 6,
        round("q-timer", "timer", function(next) togglePomodoro(next.state, next.data.seconds) end,
            if running then "Pause the pomodoro" else "Start the pomodoro", running),
        round("q-mute", if muted then "speaker.slash.fill" else "speaker.wave.2.fill", "volume mute",
            if muted then "Unmute" else "Mute", muted),
        round("q-windows", "square.grid.2x2", "open-command-palette windows", "Find a window"),
        round("q-pin", if pinned then "pin.fill" else "pin", function(next) next.state.pinned = not next.state.pinned end,
            if pinned then "Let it close when the mouse leaves" else "Keep it open", pinned) }
end

-- Tabs --------------------------------------------------------------------------------

-- Home: Notchy's cards, without the weather (now + timer | system) ----------------------

local RING = "M12 2.5 A9.5 9.5 0 1 1 12 21.5 A9.5 9.5 0 1 1 12 2.5"
local HISTORY = 40 -- CPU samples in the System card's graph

local function arc(value: number): string
    if value >= 0.999 then
        return RING
    end
    local angle = value * 2 * math.pi
    return string.format("M12 2.5 A9.5 9.5 0 %d 1 %.2f %.2f", if angle > math.pi then 1 else 0,
        12 + 9.5 * math.sin(angle), 12 - 9.5 * math.cos(angle))
end

-- A ring filled to `percent`, with the value in its middle.
local function gauge(key: string, percent: number, size: number, color: string)
    local ring = { key = key, w = size, h = size,
        ui.path{ w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = RING, border = TRACK, borderWidth = 3 } }
    if percent > 0.5 then
        ring[#ring + 1] = ui.path{ w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = arc(math.min(percent, 100) / 100),
            border = color, borderWidth = 3, animate = "ease" }
    end
    ring[#ring + 1] = ui.text{ text = string.format("%d%%", math.round(percent)), size = 13, weight = "semibold",
        color = TEXT }
    return ui.stack(ring)
end

-- `top` is the value at the graph's top edge (100 unless given), so a quiet CPU still shows its shape.
local function sparkline(values: { number }, w: number, h: number, color: string, top: number?)
    local scale = 100 / (top or 100)
    if #values < 2 then
        return ui.box{ w = w, h = h }
    end
    local last = #values - 1
    local line = {}
    for index, value in values do
        line[#line + 1] = string.format("%s%d %.1f", if index == 1 then "M" else "L", index - 1,
            100 - math.min(100, value * scale))
    end
    local stroke = table.concat(line, " ")
    return ui.stack{ w = w, h = h,
        ui.path{ w = w, h = h, viewBox = { 0, -4, last, 108 },
            d = stroke .. string.format(" L%d 104 L0 104 Z", last), fill = color .. "1A" },
        ui.path{ w = w, h = h, viewBox = { 0, -4, last, 108 }, d = stroke, border = color, borderWidth = 1.4 } }
end

-- Keeps the last CPU readings for the System card; runs on every render, so the graph is
-- already full when the panel opens.
local function sampleCpu(ctx)
    local state = ctx.state
    local history = state.cpuHistory
    if type(history) ~= "table" then
        history = {}
        state.cpuHistory = history
    end
    local cpu = ctx.data.cpu
    if cpu and state.cpuSampledAt ~= ctx.data.seconds then
        state.cpuSampledAt = ctx.data.seconds
        history[#history + 1] = cpu
        if #history > HISTORY then
            table.remove(history, 1)
        end
    end
    return history
end

local function panelCard(key: string, w: number, h: number, action, body)
    return ui.stack{ key = key, w = w, h = h, radius = 16, fill = CARD, border = CARD_LINE, borderWidth = 1,
        hover = if action then "#FFFFFF1C" else nil, onClick = action, body }
end

local function cardTitle(w: number, symbol: string, title: string, chevron: boolean?, trailing: any?)
    local row = { w = w, h = 16, gap = 6,
        ui.symbol{ name = symbol, size = 12, color = DIM },
        ui.text{ text = title, size = 13, weight = "semibold", color = TEXT },
        ui.box{ grow = 1 } }
    if trailing then
        row[#row + 1] = trailing
    end
    if chevron then
        row[#row + 1] = ui.symbol{ name = "chevron.right", size = 10, weight = "semibold", color = FAINT }
    end
    return ui.row(row)
end

local function cardBody(w: number, gap: number)
    return { w = w - 24, gap = gap, center = false, align = "top", dy = 12 }
end

-- A meeting link in the event's location (Zoom, Meet, Teams…), for the Join button.
local function meetingLink(event): string?
    return string.match(text(event.location), "https?://[^%s<>\"]+")
end

local function eventColor(event): string
    return if string.sub(text(event.color), 1, 1) == "#" then event.color else DIM
end

local function nowCard(ctx, w: number, h: number)
    local calendar = ctx.data.calendar
    local now = ctx.data.seconds
    local inner = w - 24
    local body = cardBody(w, 6)
    body[#body + 1] = cardTitle(inner, "calendar", "Now", true)
    if not calendar or calendar.access ~= "full" then
        local undecided = calendar ~= nil and calendar.access == "notDetermined"
        body[#body + 1] = ui.row{ key = "calendar-access", gap = 6, pad = 6, radius = 8, fill = "#FFFFFF14",
            hover = HOVER, onClick = if undecided then "calendar authorize" else "calendar settings",
            ui.symbol{ name = if undecided then "calendar.badge.plus" else "lock.fill", size = 11, color = TEXT },
            ui.text{ text = if not calendar then "Loading…"
                elseif undecided then "Allow Calendar access" else "Open Calendar privacy settings",
                size = 11, weight = "medium", color = TEXT } }
        return panelCard("now-card", w, h, "calendar open", ui.column(body))
    end
    local upcoming = {}
    for _, event in calendar.events do
        if not event.allDay and event["end"] > now and event.start - now < 12 * 3600 then
            upcoming[#upcoming + 1] = event
        end
    end
    table.sort(upcoming, function(a, b) return a.start < b.start end)
    local first, second = upcoming[1], upcoming[2]
    if not first then
        body[#body + 1] = ui.stack{ key = "clear", w = inner, h = h - 12 - 16 - 6 - 12,
            ui.column{ gap = 6,
                ui.symbol{ name = "calendar.badge.checkmark", size = 22, color = FAINT },
                ui.text{ text = "Nothing else today", size = 12, color = DIM } } }
        return panelCard("now-card", w, h, "calendar open", ui.column(body))
    end
    local ongoing = first.start <= now
    local minutes = math.ceil(((if ongoing then first["end"] else first.start) - now) / 60)
    local status = if ongoing then tostring(minutes) .. " min left"
        elseif minutes < 60 then "In " .. tostring(minutes) .. " min" else first.time
    local link = meetingLink(first)
    local titleWidth = inner - (if link then 66 else 0)
    local headline = { w = inner, gap = 6,
        ui.column{ w = titleWidth, gap = 2, center = false,
            ui.text{ text = first.title, size = 13, weight = "semibold", color = TEXT, maxWidth = titleWidth },
            ui.text{ text = status, size = 11, weight = "medium", color = if ongoing then GREEN else eventColor(first) } } }
    if link then
        headline[#headline + 1] = ui.box{ grow = 1 }
        headline[#headline + 1] = ui.row{ key = "join", h = 24, gap = 4, pad = 8, radius = 12, fill = GREEN,
            hover = "#34E06A", pressScale = 0.95, onClick = function() omniwm.open(link) end, help = link,
            ui.symbol{ name = "video.fill", size = 10, color = TEXT },
            ui.text{ text = "Join", size = 11, weight = "semibold", color = TEXT } }
    end
    body[#body + 1] = ui.row(headline)
    if ongoing then
        body[#body + 1] = bar("event-progress", inner, (now - first.start) / math.max(1, first["end"] - first.start),
            GREEN)
    end
    if second then
        body[#body + 1] = ui.column{ key = "next-event", gap = 2, center = false,
            ui.text{ text = second.title, size = 12, weight = "semibold", color = TEXT, maxWidth = inner },
            ui.text{ text = second.time, size = 11, weight = "medium", color = eventColor(second) } }
    end
    return panelCard("now-card", w, h, "calendar open", ui.column(body))
end

local function timerCard(ctx, w: number, h: number, pomo, now: number, info)
    local inner = w - 24
    local running = pomo.phase ~= "idle"
    local body = cardBody(w, 6)
    local done = if pomo.day == ctx.format.date(now, "yyyy-MM-dd") then pomo.today or 0 else 0
    body[#body + 1] = cardTitle(inner, "timer", "Timer", true, if done > 0
        then ui.text{ text = tostring(done) .. " focus today", size = 11, weight = "medium", color = DIM } else nil)
    local caption = if running then PHASES[pomo.phase] .. (if pomo.paused then " · paused" else "") else "Ready"
    body[#body + 1] = ui.row{ w = inner, h = 32, gap = 8,
        ui.text{ text = if running then mmss(remaining(pomo, now)) else "--:--", size = 24, weight = "semibold",
            color = if running then phaseColor(pomo) else DIM, reserve = "00:00" },
        ui.text{ text = caption, size = 11, weight = "medium", color = DIM },
        ui.box{ grow = 1 },
        button("home-pomodoro", if running and not pomo.paused then "pause.fill" else "play.fill",
            function(next) togglePomodoro(next.state, next.data.seconds) end, 12) }
    -- "Needs you" first, so a long agent name is what gets cut.
    local agents = if info.prompt then "Needs you · " .. text(info.who)
        elseif info.working > 0 then tostring(info.working) .. " working" else "No agents at work"
    local line = { key = "home-agents", w = inner, h = 16, gap = 6, onClick = openTab("agents"), help = "Agents" }
    local used = 0
    if info.mounted and info.busy > 0 then
        local troupeW = troupeWidth(ctx, info.busy)
        line[#line + 1] = ui.component{ key = "home-troupe", id = CREW, view = "troupe", w = troupeW, h = 15,
            props = crewProps(info) }
        used = troupeW + 6
    end
    line[#line + 1] = ui.text{ text = agents, size = 11, weight = if info.prompt then "medium" else nil,
        color = if info.prompt then YELLOW else DIM, maxWidth = inner - used }
    body[#body + 1] = ui.row(line)
    return panelCard("timer-card", w, h, openTab("timer"), ui.column(body))
end

-- The Mac's sensors, averaged by OmniWM: "CPU 52° · GPU 48°", the thermometer warming with the CPU.
local function temperatures(thermal)
    if type(thermal) ~= "table" or type(thermal.cpu) ~= "number" then
        return nil
    end
    local parts = { "CPU " .. tostring(math.round(thermal.cpu)) .. "°" }
    if type(thermal.gpu) == "number" then
        parts[#parts + 1] = "GPU " .. tostring(math.round(thermal.gpu)) .. "°"
    end
    local heat = if thermal.cpu >= 90 then RED elseif thermal.cpu >= 70 then ORANGE else GREEN
    return ui.row{ key = "thermal", gap = 4,
        ui.symbol{ name = "thermometer.medium", size = 11, color = heat },
        ui.text{ text = table.concat(parts, " · "), size = 11, weight = "medium", color = DIM } }
end

local function systemCard(ctx, w: number, h: number, history: { number })
    local data = ctx.data
    local inner = w - 24
    local memory = data.system and data.system.memory
    local dials = { { "cpu", data.cpu, "CPU", ORANGE }, { "gpu", data.gpu, "GPU", CYAN },
        { "memory", data.memory, if memory then string.format("Memory · %d/%d GB", math.round(memory.used / 2 ^ 30),
            math.round(memory.total / 2 ^ 30)) else "Memory", PURPLE } }
    local row = { w = inner, h = 76 }
    for _, dial in dials do
        if dial[2] then
            row[#row + 1] = ui.column{ key = dial[1], gap = 6, grow = 1,
                gauge(dial[1] .. "-ring", dial[2], 56, dial[4]),
                ui.text{ text = dial[3], size = 10, weight = "medium", color = DIM } }
        end
    end
    local peak = 0
    for _, value in history do
        peak = math.max(peak, value)
    end
    local graph = h - 24 - 16 - 14 - 76 - 14 - 10 - 14
    local body = cardBody(w, 0)
    body[#body + 1] = cardTitle(inner, "gauge.with.dots.needle.67percent", "System", nil, temperatures(data.thermal))
    body[#body + 1] = ui.box{ w = inner, h = 14 }
    body[#body + 1] = ui.row(row)
    body[#body + 1] = ui.box{ w = inner, h = 14 }
    body[#body + 1] = sparkline(history, inner, graph, ORANGE, math.max(20, peak * 1.25))
    body[#body + 1] = ui.box{ w = inner, h = 10 }
    local network = data.network
    local function speed(bytes: number): string
        return ctx.format.bytes(bytes, "file") .. "/s"
    end
    body[#body + 1] = ui.row{ w = inner, h = 14, gap = 4,
        ui.symbol{ name = "arrow.down", size = 9, weight = "semibold", color = DIM },
        ui.text{ text = speed(network and network.down or 0), size = 11, color = DIM },
        ui.box{ w = 6 },
        ui.symbol{ name = "arrow.up", size = 9, weight = "semibold", color = DIM },
        ui.text{ text = speed(network and network.up or 0), size = 11, color = DIM },
        ui.box{ grow = 1 },
        ui.text{ text = if data.battery then "Battery " .. tostring(data.battery) .. "%"
            .. (if data.charging == true then " ⚡" else "") else "", size = 11, color = DIM } }
    return panelCard("system-card", w, h, nil, ui.column(body))
end

local function homeTab(ctx, inner: number, info, pomo, now: number, history: { number })
    local column = math.floor((inner - 10) / 2)
    local nowH = math.floor((HOME_H - 10) * 0.55)
    return ui.row{ key = "home", w = inner, h = HOME_H, gap = 10,
        ui.column{ key = "left", w = column, h = HOME_H, gap = 10,
            nowCard(ctx, column, nowH),
            timerCard(ctx, column, HOME_H - 10 - nowH, pomo, now, info) },
        systemCard(ctx, inner - column - 10, HOME_H, history) }, HOME_H
end

-- Music: cover | track, seek, transport and volume | synced lyrics --------------------

local function lyricLines(ctx, position: number, width: number)
    local data = ctx.data.lyrics
    local message = if not data then nil
        elseif data.access == "off" then "Lyrics are off in OmniWM Settings"
        elseif data.access == "blocked" then "Lyrics are blocked"
        elseif data.status == "loading" then "Loading lyrics…"
        elseif data.status ~= "synced" or #data.lines == 0 then "No synced lyrics for this song"
        else nil
    if not data then
        return nil
    end
    local column = { key = "lyrics", w = width, gap = 6, center = false }
    if message then
        column[#column + 1] = ui.text{ text = message, size = 12, color = FAINT, maxWidth = width }
        return ui.column(column)
    end
    local current = 1
    for index, entry in data.lines do
        if entry.time > position then
            break
        end
        current = index
    end
    for index = math.max(1, current - 1), math.min(#data.lines, current + 3) do
        local entry = data.lines[index]
        local now = index == current
        column[#column + 1] = ui.row{ key = "line-" .. index, w = width, pad = 2, radius = 6, hover = HOVER,
            onClick = string.format("media seek %.1f", entry.time),
            ui.text{ text = if entry.text ~= "" then entry.text else "♪", size = if now then 14 else 12,
                weight = if now then "semibold" else "medium", color = if now then TEXT else FAINT,
                maxWidth = width - 4, lines = 2 } }
    end
    return ui.column(column)
end

local function musicTab(ctx, inner: number, media: Media?)
    if not media then
        return ui.text{ key = "nothing", text = "Nothing playing", size = 12, color = DIM }, 18
    end
    local controlsW = 270
    local lyricsW = inner - MUSIC_COVER - controlsW - 2 * 22
    local value = progress(ctx, media)
    local duration = media.duration
    local position = if value and duration then value * duration else 0
    local repeating = media.repeatMode == "one" or media.repeatMode == "all"
    local controls = { key = "controls", w = controlsW, gap = 8, center = false,
        ui.column{ gap = 2, center = false,
            ui.text{ text = media.title, size = 15, weight = "semibold", color = TEXT, maxWidth = controlsW },
            ui.text{ text = text(media.artist), size = 12, color = DIM, maxWidth = controlsW },
            ui.text{ text = text(media.album), size = 11, color = FAINT, maxWidth = controlsW } } }
    if value and duration then
        controls[#controls + 1] = ui.column{ key = "seek", w = controlsW, gap = 2,
            ui.slider{ key = "seek-slider", w = controlsW, h = 16, value = value, color = TEXT,
                onChange = function(_, event)
                    if event.value and event.phase == "ended" then
                        omniwm.run(string.format("media seek %.1f", event.value * duration))
                    end
                end },
            ui.row{ w = controlsW,
                ui.text{ text = mmss(position), size = 10, color = DIM },
                ui.box{ grow = 1 },
                ui.text{ text = "-" .. mmss(duration - position), size = 10, color = DIM } } }
    end
    controls[#controls + 1] = ui.row{ key = "transport", w = controlsW, gap = 10,
        ui.stack{ key = "shuffle", w = 28, h = 28, radius = 14, hover = HOVER, onClick = "media shuffle", help = "Shuffle",
            ui.symbol{ name = "shuffle", size = 12, color = if media.shuffle then GREEN else FAINT } },
        ui.box{ grow = 1 },
        button("previous", "backward.fill", "media previous", 14, "Previous", 34),
        button("toggle", if media.playing then "pause.fill" else "play.fill", "media toggle", 20, nil, 42),
        button("next", "forward.fill", "media next", 14, "Next", 34),
        ui.box{ grow = 1 },
        ui.stack{ key = "repeat", w = 28, h = 28, radius = 14, hover = HOVER, onClick = "media repeat", help = "Repeat",
            ui.symbol{ name = if media.repeatMode == "one" then "repeat.1" else "repeat", size = 12,
                color = if repeating then GREEN else FAINT } } }
    local volume = ctx.data.volume
    if volume then
        controls[#controls + 1] = ui.row{ key = "volume", w = controlsW, gap = 8,
            ui.symbol{ name = "speaker.fill", size = 10, color = DIM },
            ui.slider{ key = "volume-slider", w = controlsW - 44, h = 16, value = math.clamp(volume / 100, 0, 1),
                color = TEXT, onChange = function(_, event)
                    if event.value then
                        omniwm.run(string.format("volume set %d", math.round(event.value * 100)))
                    end
                end },
            ui.symbol{ name = "speaker.wave.3.fill", size = 10, color = DIM } }
    end
    local row = { key = "music", w = inner, h = MUSIC_H, gap = 22,
        ui.stack{ key = "cover", w = MUSIC_COVER, h = MUSIC_COVER, onClick = "media open", help = "Open " .. media.app,
            pressScale = 0.97, cover(media, MUSIC_COVER, 14) },
        ui.column(controls) }
    local lyrics = lyricLines(ctx, position, lyricsW)
    if lyrics then
        row[#row + 1] = lyrics
    end
    return ui.row(row), MUSIC_H
end

local function agentsTab(ctx, inner: number, info)
    if not info.mounted then
        return ui.text{ key = "no-crew", text = "The crew component is off in shell.toml", size = 12,
            color = DIM }, 18
    end
    return ui.component{ key = "crew-office", id = CREW, view = "office", w = inner, h = OFFICE_H,
        props = crewProps(info) }, OFFICE_H
end

local function timerTab(ctx, inner: number, pomo, now: number)
    local running = pomo.phase ~= "idle"
    local session = ((pomo.count or 0) % 4) + (if pomo.phase == "focus" then 1 else 0)
    local caption = if running then PHASES[pomo.phase] .. (if pomo.paused then " · paused" else "")
        .. (if pomo.phase == "focus" then " · session " .. tostring(math.max(1, session)) .. " of 4" else "")
        else "Ready for a 25-minute focus"
    local pips = { key = "pips", gap = 6 }
    for index = 1, 4 do
        pips[#pips + 1] = ui.box{ key = "pip-" .. index, w = 8, h = 8, radius = 4,
            fill = if index <= (pomo.count or 0) % 4 then TOMATO else TRACK }
    end
    local auto = pomo.auto ~= false
    return ui.column{ key = "timer", w = inner, gap = 10,
        ui.text{ key = "caption", text = caption, size = 12, color = DIM },
        ui.text{ key = "clock", text = mmss(remaining(pomo, now)), size = 42, weight = "semibold",
            color = if running then phaseColor(pomo) else TEXT, reserve = "00:00" },
        ui.row(pips),
        ui.row{ key = "controls", gap = 14,
            button("reset", "arrow.counterclockwise", function(next)
                stopPomodoro(next.state, next.data.seconds, true)
            end, 13, "Stop", 36),
            button("play", if running and not pomo.paused then "pause.fill" else "play.fill", function(next)
                togglePomodoro(next.state, next.data.seconds)
            end, 18, if running and not pomo.paused then "Pause" else "Start", 44),
            button("skip", "forward.end.fill", function(next)
                if pomodoro(next.state).phase ~= "idle" then
                    advance(next.state, next.data.seconds, 0)
                end
            end, 13, "Skip", 36) },
        ui.row{ key = "auto", w = inner, h = 28, gap = 10, radius = 14, pad = 6, hover = HOVER,
            onClick = function(next)
                local state = pomodoro(next.state)
                state.auto = not (state.auto ~= false)
                savePomodoro(next.state)
            end,
            ui.stack{ key = "switch", w = 30, h = 18, radius = 9, fill = if auto then GREEN else TRACK, animate = CONTENT,
                ui.box{ key = "knob", w = 14, h = 14, radius = 7, fill = TEXT, align = if auto then "trailing" else "leading",
                    dx = if auto then -2 else 2, animate = CONTENT } },
            ui.column{ gap = 1, center = false,
                ui.text{ text = "Starts with your agents", size = 12, weight = "semibold", color = TEXT },
                ui.text{ text = "Starts when an agent gets to work, stops after 10 idle minutes", size = 10,
                    color = DIM, maxWidth = inner - 60 } } } }, 14 + 50 + 8 + 44 + 28 + 4 * 10
end

local function shelfTile(item)
    local resource = item.resource
    local thumbnail = if ready(item) and (resource.kind == "file" or resource.kind == "image")
        then ui.image{ image = resource, thumbnail = 72, w = 34, h = 34, radius = 6 }
        else ui.symbol{ name = if resource.kind == "url" then "link" elseif resource.kind == "text"
            then "text.alignleft" else "doc", size = 18, color = DIM, w = 34, h = 34 }
    return ui.column{ key = "item-" .. tostring(item.id), w = TILE_W, h = TILE_H, gap = 5, radius = 10,
        hover = HOVER, pressScale = 0.95,
        help = item.name .. if item.failed then " (not saved)" else "",
        dragItems = if ready(item) then { resource } else nil,
        onClick = function() shelfOpen(item) end,
        onRightClick = function(next) shelfRemove(next.state, item.id) end,
        thumbnail,
        ui.text{ text = item.name, size = 9, color = DIM, maxWidth = TILE_W - 6 } }
end

local function shelfTab(ctx, inner: number, dropping: boolean)
    local state = ctx.state
    local items = if state.shelf then state.shelf.items else {}
    local highlight = state.dropHover == true or dropping
    if #items == 0 then
        return ui.stack{ key = "dropzone", w = inner, h = 96, radius = 16, animate = CONTENT,
            fill = if highlight then "#FFFFFF1F" else CARD, border = if highlight then "#FFFFFF59" else nil,
            borderWidth = if highlight then 1.5 else nil,
            ui.column{ gap = 8,
                ui.symbol{ name = "tray.and.arrow.down.fill", size = 22, color = if highlight then TEXT else DIM },
                ui.text{ text = if highlight then "Drop to keep it here" else "Drag files onto the notch to keep them here",
                    size = 12, weight = "medium", color = DIM } } }, 96
    end
    local perRow = math.max(1, math.floor((inner + 6) / (TILE_W + 6)))
    local rows = math.min(2, math.ceil(#items / perRow))
    local capacity = rows * perRow
    local grid = { key = "grid", w = inner, gap = 6, center = false }
    for row = 1, rows do
        local line = { key = "row-" .. row, gap = 6, h = TILE_H }
        for column = 1, perRow do
            local index = (row - 1) * perRow + column
            if index <= #items then
                if index == capacity and #items > capacity then
                    line[#line + 1] = ui.stack{ key = "more", w = TILE_W, h = TILE_H, radius = 10, fill = CARD,
                        ui.text{ text = "+" .. tostring(#items - capacity + 1), size = 12, weight = "semibold",
                            color = DIM } }
                else
                    line[#line + 1] = shelfTile(items[index])
                end
            end
        end
        grid[#grid + 1] = ui.row(line)
    end
    grid[#grid + 1] = ui.row{ key = "shelf-actions", w = inner, h = 28, gap = 8,
        ui.text{ text = tostring(#items) .. " items · click to open, right-click to remove", size = 10, color = DIM },
        ui.box{ grow = 1 },
        button("shelf-airdrop", "square.and.arrow.up", airdrop, 12, "AirDrop"),
        button("shelf-clear", "trash", shelfClear, 12, "Clear") }
    return ui.column(grid), rows * TILE_H + (rows - 1) * 6 + 6 + 28
end

-- Island ------------------------------------------------------------------------------

-- A body hanging from the top edge: concave shoulders up top, rounded corners below.
local function outline(w: number, h: number, radius: number, shoulder: number): string
    local s = shoulder
    local r = math.max(0, math.min(radius, (w - 2 * s) / 2, h - s))
    return string.format(
        "M0 0 H%.2f Q%.2f 0 %.2f %.2f V%.2f Q%.2f %.2f %.2f %.2f H%.2f Q%.2f %.2f %.2f %.2f V%.2f Q%.2f 0 0 0 Z",
        w, w - s, w - s, s,
        h - r, w - s, h, w - s - r, h,
        s + r, s, h, s, h - r,
        s, s)
end

local function wants(types: { string }?): boolean
    for _, kind in types or {} do
        if table.find(DROP_KINDS, kind) then
            return true
        end
    end
    return false
end

local function hover(ctx, event)
    if event.phase == "began" then
        ctx.state.hovered = true
    elseif event.phase == "ended" then
        ctx.state.hovered = false
        if not ctx.state.pinned then
            ctx.state.open = false
        end
    end
end

local function click(ctx)
    if not ctx.state.open then
        ctx.state.open = true
        ctx.state.tab = ctx.state.tab or "home"
    end
end

local function close(ctx)
    ctx.state.open = false
    ctx.state.hovered = false
end

local function scroll(ctx, event)
    if ctx.state.open then
        return
    end
    if event.momentum and event.momentum ~= "none" then
        return
    end
    local raw = if math.abs(event.dx) > math.abs(event.dy) then -event.dx else event.dy
    local delta = if event.precise then raw / PRECISE_STEP else raw
    local total = ctx.state.scroll or 0
    if total * delta < 0 then
        total = 0
    end
    total += delta
    local steps = if total >= 0 then math.floor(total) else math.ceil(total)
    ctx.state.scroll = total - steps
    if steps ~= 0 then
        omniwm.run(if steps > 0 then "command switch-workspace prev" else "command switch-workspace next")
    end
end

local function dropHover(ctx, event)
    ctx.state.dropHover = event.phase == "entered"
end

local function drop(ctx, event)
    local state = ctx.state
    state.dropHover = false
    if not state.shelf then
        shelfLoad(state)
    end
    shelfAdd(state, event.items or {})
    flash(state, "shelf")
end

-- The one line a hover shows under the pill.
local function peek(ctx, info, media: Media?, pomo, now: number, workspaces, width: number)
    local inner = width - 2 * (SHOULDER + 14)
    if media then
        local textWidth = inner - 22 - 10 - 28 - 10
        return ui.row{ key = "peek-media", w = inner, h = 28, gap = 10,
            cover(media, 22, 5),
            ui.text{ text = media.title .. (if text(media.artist) ~= "" then " — " .. media.artist else ""), size = 12,
                color = TEXT, maxWidth = textWidth },
            ui.box{ grow = 1 },
            button("peek-toggle", if media.playing then "pause.fill" else "play.fill", "media toggle", 12) }
    end
    if pomo.phase ~= "idle" then
        return ui.row{ key = "peek-timer", w = inner, h = 28, gap = 10,
            ui.symbol{ name = "timer", size = 13, color = phaseColor(pomo) },
            ui.text{ text = PHASES[pomo.phase] .. " · " .. mmss(remaining(pomo, now)), size = 12, weight = "semibold",
                color = TEXT },
            ui.box{ grow = 1 },
            button("peek-pomodoro", if pomo.paused then "play.fill" else "pause.fill",
                function(next) togglePomodoro(next.state, next.data.seconds) end, 12) }
    end
    if info.working > 0 then
        return ui.row{ key = "peek-agents", w = inner, h = 28, gap = 8,
            ui.symbol{ name = "sparkle", size = 12, color = "#D97757" },
            ui.text{ text = tostring(info.working) .. " working" .. (if info.doing then " · " .. info.doing else ""),
                size = 12, color = TEXT, maxWidth = inner - 30 } }
    end
    local right, rightWidth = dots(workspaces)
    return ui.row{ key = "peek-idle", w = inner, h = 28, gap = 10,
        ui.text{ text = ctx.data.clock, size = 12, weight = "semibold", color = TEXT },
        ui.box{ grow = 1 },
        ui.stack{ w = rightWidth, h = 6, right } }
end

function trigger(ctx, event)
    if event.name == "update" then
        ctx.state.agents = event.value
    elseif event.name == "agents" then
        local list = json.decode(event.value or "[]")
        if type(list) == "table" then
            ctx.state.crew = list
        end
    elseif event.name == "toggle" then
        if ctx.state.open then
            close(ctx)
        else
            click(ctx)
        end
    elseif event.name == "pomodoro" then
        -- `omniwmctl shell trigger notch pomodoro [stop|skip]`; no value starts or pauses it.
        local now = ctx.data.seconds
        if event.value == "stop" then
            stopPomodoro(ctx.state, now, true)
        elseif event.value == "skip" then
            if pomodoro(ctx.state).phase ~= "idle" then
                advance(ctx.state, now, 0)
            end
        else
            togglePomodoro(ctx.state, now)
        end
    elseif event.name == "open" then
        -- `omniwmctl shell trigger notch open <home|agents|music|timer|shelf>`; none closes it.
        local known = false
        for _, tab in TABS do
            known = known or tab.id == event.value
        end
        if known then
            ctx.state.tab = event.value
            ctx.state.open = true
        else
            close(ctx)
        end
    end
end

function render(ctx)
    local island = ctx.data.island
    if not island then
        return ui.box{ w = 0, h = 0 }
    end
    local state = ctx.state
    if not state.shelf then
        shelfLoad(state)
    end
    local available = math.max(1, island.size.w)
    local tall = math.max(1, island.size.h)
    local notch = island.notch or { x = available / 2 - 90, w = 180, h = math.max(24, island.menuBar) }
    local center = notch.x + notch.w / 2
    local now = ctx.data.seconds
    local workspaces = ctx.data.workspaces or {}
    local media = ctx.data.media
    if media and (media.title == nil or media.title == "") then
        media = nil
    end
    local info = crewInfo(ctx)
    for _, component in ctx.data.components or {} do
        local problem = if component.error then component.id .. ": " .. component.error else nil
        if problem and remember(state, "componentError", problem) ~= problem then
            omniwm.log("component " .. problem)
        end
    end
    observe(ctx, workspaces)
    tick(ctx, info.working)
    local pomo = pomodoro(state)
    local history = sampleCpu(ctx)

    local drag = island.drag
    local dropping = drag ~= nil and drag.active == true and wants(drag.types)
    local alerting = info.prompt ~= nil and state.dismissed ~= info.prompt
    local mode = if dropping or state.open then "open" elseif alerting then "alert"
        elseif state.hovered then "peek" else "rest"

    local width, height, radius, shoulder = notch.w - 4, notch.h, 9, 0
    local children = {}

    if mode == "open" then
        width = math.min(available, PANEL_WIDTH)
        local inner = width - 2 * INSET
        local tab = if dropping then "shelf" else state.tab or "home"
        local body, bodyHeight
        if tab == "agents" then
            body, bodyHeight = agentsTab(ctx, inner, info)
        elseif tab == "music" then
            body, bodyHeight = musicTab(ctx, inner, media)
        elseif tab == "timer" then
            body, bodyHeight = timerTab(ctx, inner, pomo, now)
        elseif tab == "shelf" then
            body, bodyHeight = shelfTab(ctx, inner, dropping)
        else
            body, bodyHeight = homeTab(ctx, inner, info, pomo, now, history)
        end
        height = math.min(tall, notch.h + 10 + bodyHeight + 16)
        radius, shoulder = 26, SHOULDER
        -- Notchy's header sits beside the notch: the tabs on the left, the quick actions on the right.
        local wing = (width - notch.w) / 2 - INSET - 8
        local band = (notch.h - TABS_H) / 2
        children[#children + 1] = ui.stack{ key = "tabs-wing", w = wing, h = TABS_H, align = "top",
            dx = -(notch.w / 2 + 8 + wing / 2), dy = band, appear = FADE_IN, exit = FADE_OUT,
            ui.row{ w = wing, h = TABS_H, tabs(ctx, tab, info), ui.box{ grow = 1 } } }
        children[#children + 1] = ui.stack{ key = "quick-wing", w = wing, h = TABS_H, align = "top",
            dx = notch.w / 2 + 8 + wing / 2, dy = band, appear = FADE_IN, exit = FADE_OUT,
            ui.row{ w = wing, h = TABS_H, ui.box{ grow = 1 }, quick(ctx, pomo) } }
        children[#children + 1] = ui.stack{ key = "tab-" .. tab, w = inner, h = bodyHeight, align = "top",
            dy = notch.h + 10, appear = FADE_IN, exit = FADE_OUT, body }
    elseif mode == "alert" then
        width = math.min(available, ALERT_WIDTH)
        height = math.min(tall, notch.h + 10 + HELP_H + 14)
        radius, shoulder = 24, SHOULDER
        local side = (width - notch.w) / 2
        children[#children + 1] = ui.row{ key = "alert-title", gap = 6, align = "top",
            dx = -(notch.w + side) / 2, dy = (notch.h - 14) / 2,
            ui.box{ w = 7, h = 7, radius = 3.5, fill = YELLOW },
            ui.text{ text = "Needs you", size = 12, weight = "semibold", color = YELLOW } }
        children[#children + 1] = ui.stack{ key = "alert-later", w = 56, h = 22, radius = 11, fill = "#FFFFFF1F",
            hover = "#FFFFFF33", align = "top", dx = (notch.w + side) / 2, dy = (notch.h - 22) / 2,
            onClick = function(next) next.state.dismissed = info.prompt end, help = "Hide until another agent asks",
            ui.text{ text = "Later", size = 11, weight = "semibold", color = TEXT } }
        children[#children + 1] = ui.stack{ key = "help-card", w = width - 2 * INSET, h = HELP_H, align = "top",
            dy = notch.h + 10, appear = FADE_IN, exit = FADE_OUT,
            ui.component{ key = "help", id = CREW, view = "help", w = width - 2 * INSET, h = HELP_H,
                props = crewProps(info) } }
    else
        local playing = media ~= nil and media.playing
        local left, leftWidth, right, rightWidth = flashed(ctx, workspaces)
        local leftKind, rightKind = state.flash, state.flash
        if not left and mode ~= "peek" then
            -- At rest only the brief flashes (and the "needs you" card) show: the rest waits for a hover.
            leftWidth, rightWidth = 0, 0
            leftKind, rightKind = nil, nil
        elseif not left then
            leftWidth, rightWidth = 0, 0
            leftKind, rightKind = nil, nil
            if info.mounted and info.busy > 0 then
                left, leftWidth = troupe(ctx, info)
                leftKind = "crew"
            elseif playing and media.artwork then
                left, leftWidth = ui.image{ key = "art", image = media.artwork, w = 18, h = 18, radius = 4 }, 18
                leftKind = "media"
            end
            local items = { key = "live", gap = 10 }
            if pomo.phase ~= "idle" then
                local chip, chipWidth = timerChip(ctx, pomo, now)
                items[#items + 1] = chip
                rightWidth += chipWidth
            end
            if playing then
                items[#items + 1] = ui.shader{ key = "equalizer", source = EQUALIZER, w = 20, h = 14, fps = 30,
                    values = { 1 } }
                rightWidth += (if rightWidth > 0 then 10 else 0) + 20
            end
            if #items > 0 then
                right = ui.row(items)
                rightKind = "live"
            end
        end
        local extras = if mode == "peek" then marks(ctx, info) else {}
        if #extras > 0 then
            local row = { key = "right-row", gap = 8 }
            if right then
                row[1] = right
            end
            local marksRow = { key = "marks", gap = 5 }
            for _, mark in extras do
                marksRow[#marksRow + 1] = ui.box{ key = mark.key, w = 6, h = 6, radius = 3, fill = mark.color,
                    help = mark.help }
            end
            row[#row + 1] = ui.row(marksRow)
            rightWidth += (if rightWidth > 0 then 8 else 0) + #extras * 6 + (#extras - 1) * 5
            right = ui.row(row)
            rightKind = rightKind or "marks"
        end
        local content = math.max(leftWidth, rightWidth)
        local wing = if content > 0 then content + 2 * PAD else 0
        if content > 0 or mode == "peek" then
            radius, shoulder = 12, SHOULDER
            width = math.min(available, notch.w + 2 * (wing + SHOULDER))
        end
        if mode == "peek" then
            local strip = false
            for _, component in ctx.data.components or {} do
                strip = strip or (component.id == SPACES and component.enabled)
            end
            width = math.max(width, math.min(available, if strip then PEEK_WIDTH else notch.w + 2 * (90 + SHOULDER)))
            height = notch.h + PEEK_H + (if strip then STRIP_H + 8 else 0)
            radius = 18
            local inner = width - 2 * (SHOULDER + 14)
            children[#children + 1] = ui.stack{ key = "peek", w = inner, h = 28, align = "top",
                dy = notch.h + 4, appear = FADE_IN, exit = FADE_OUT,
                peek(ctx, info, media, pomo, now, workspaces, width) }
            if strip then
                children[#children + 1] = ui.stack{ key = "spaces-strip", w = inner, h = STRIP_H, align = "top",
                    dy = notch.h + 4 + 28 + 6, appear = FADE_IN, exit = FADE_OUT,
                    ui.component{ key = "spaces", id = SPACES, view = "strip", w = inner, h = STRIP_H } }
            end
        end
        if left then
            children[#children + 1] = ui.stack{ key = "left-" .. (leftKind or "none"), w = wing, h = notch.h,
                align = "top", dx = -(notch.w + wing) / 2, appear = APPEAR, exit = EXIT, left }
        end
        if right then
            children[#children + 1] = ui.stack{ key = "right-" .. (rightKind or "none"), w = wing, h = notch.h,
                align = "top", dx = (notch.w + wing) / 2, appear = APPEAR, exit = EXIT, right }
        end
    end

    local frame = { key = "island", w = width, h = height, align = "top", dx = center - available / 2,
        animate = SHAPE, onHover = hover, hoverDelay = 0.06, hoverGrace = 0.35,
        onClick = click, onScroll = scroll, onOutsidePress = if mode == "open" and not state.pinned then close else nil,
        accepts = DROP_KINDS, onDrop = drop, onDropHover = dropHover }
    -- One black shape in every mode, so the panel grows out of the notch.
    frame.fill = BLACK
    frame[1] = ui.path{ key = "shape", w = width, h = height, viewBox = { 0, 0, width, height }, mask = true,
        d = outline(width, height, radius, shoulder), animate = SHAPE }
    for _, child in children do
        frame[#frame + 1] = child
    end
    return ui.stack{ w = available, h = tall, ui.stack(frame) }
end
