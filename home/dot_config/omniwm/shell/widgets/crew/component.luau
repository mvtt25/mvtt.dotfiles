-- Crew: the TUIOS agents on the notch island, drawn as pixel critters (avatar.metal).
-- Read-only: it never answers an agent. The root passes the agents that agents.sh
-- pushed as props.agents (TUIOS's after-agent-state hook runs it at every change).
-- Views: "troupe" (critters beside the notch), "help" (the card when an agent is
-- asking for your help) and "office" (the Agents tab: a pixel office where each agent
-- sits at a desk, rests on a pouf in the lounge, or takes a coffee when it just finished; a click shows
-- it under the room, with Open to go to its pane). open.sh is the provider behind Open.

local AVATAR = omniwm.asset("@self/avatar.metal")
local ROOM = omniwm.asset("@self/room.metal")
local DESK = omniwm.asset("@self/desk.metal")
local AVATAR_W, AVATAR_H = 16, 12
local TEXT = "#F5F5F7"
local DIM = "#FFFFFF99"
local FAINT = "#FFFFFF59"
local YELLOW = "#FFD60A"
local RED = "#FF453A"
local TROUPE_MAX = 3
-- The office, in its own pixels (PIX points each); the numbers match room.metal.
local PIX = 2.5
local GROUND = 58 -- the floor line things stand on
-- Three white desks on the floor between the counter and the lamp, one at each end and one in the
-- middle, of up to SEATS seats each (desk.metal draws one seat; more fit side by side).
local DESKS_FROM, DESKS_TO, SEAT_W, DESK_H, SEATS = 36, 83, 22, 22, 2 -- DESKS_TO from the right (lamp - 4)
local DESK_SLOTS = { 2, 1, 3 } -- in pane order, agents sit at the middle desk, then the left, then the right, in turn
local DETAILS_H, OPEN_W = 40, 64 --the strip under the room with the clicked agent, and its Open button
local POUFS = 3
local AT_DESK = { working = 0, needs_input = 1, errored = 2 } -- desk.metal's states; 3 is away
local MOODS = { working = 0, needs_input = 1, errored = 2 }
local ORDER = { needs_input = 1, errored = 2, working = 3, done = 4, idle = 5 }
local LABELS = { working = "working", needs_input = "needs you", errored = "error", idle = "idle", done = "done",
    none = "—", unknown = "—" }
local HARNESSES = { ["claude-code"] = "Claude", codex = "Codex", ["gemini-cli"] = "Gemini", opencode = "OpenCode" }

local function text(value): string
    return if type(value) == "string" then value else ""
end

-- The agents to draw, most urgent first.
local function roster(ctx)
    local props = if ctx.view and type(ctx.view.props) == "table" then ctx.view.props else {}
    local list = {}
    for _, agent in if type(props.agents) == "table" then props.agents else {} do
        if type(agent) == "table" and type(agent.i) == "string" and type(agent.s) == "string" then
            list[#list + 1] = agent
        end
    end
    table.sort(list, function(a, b)
        local x, y = ORDER[a.s] or 6, ORDER[b.s] or 6
        if x ~= y then
            return x < y
        end
        return text(a.n) < text(b.n)
    end)
    return list
end

local function finished(agent): boolean
    return agent.s == "done" and agent.u == true
end

local function busy(agent): boolean
    return MOODS[agent.s] ~= nil or finished(agent)
end

local function name(agent): string
    local value = text(agent.n)
    return if value ~= "" then value elseif text(agent.h) ~= "" then agent.h else "agent"
end

local function harness(agent): string
    return HARNESSES[text(agent.h)] or (if text(agent.h) ~= "" then agent.h else "An agent")
end

local function label(agent): string
    return if finished(agent) then "done, unread" else LABELS[agent.s] or agent.s
end

local function phase(id: string): number
    local sum = 0
    for index = 1, #id do
        sum += string.byte(id, index)
    end
    return (sum % 97) / 7
end

local function avatar(agent, scale: number, place: string)
    return ui.shader{ key = place .. "-" .. agent.i, source = AVATAR, w = AVATAR_W * scale, h = AVATAR_H * scale,
        fps = 12, help = name(agent) .. " — " .. label(agent),
        values = { if finished(agent) then 4 else MOODS[agent.s] or 3, phase(agent.i),
            if agent.h == "claude-code" then 1 else 0 } }
end

local function waited(ctx, agent): string
    local since = tonumber(agent.t)
    if not since or since <= 0 then
        return ""
    end
    local seconds = math.max(0, ctx.data.seconds - since / 1e9)
    if seconds < 60 then
        return "just now"
    end
    return if seconds < 3600 then tostring(math.floor(seconds / 60)) .. "m ago"
        else tostring(math.floor(seconds / 3600)) .. "h ago"
end

local function troupe(ctx)
    local list = {}
    for _, agent in roster(ctx) do
        if busy(agent) then
            list[#list + 1] = agent
        end
    end
    local row = { key = "troupe", gap = 2, h = AVATAR_H * 1.25 }
    for index = 1, math.min(#list, TROUPE_MAX) do
        row[#row + 1] = avatar(list[index], 1.25, "wing")
    end
    if #list > TROUPE_MAX then
        row[#row + 1] = ui.text{ key = "more", text = "+" .. tostring(#list - TROUPE_MAX), size = 11,
            weight = "semibold", color = DIM }
    end
    return ui.row(row)
end

-- "Claude in session-0 is asking for your help": who, where, since when, and what.
local function help(ctx)
    local width = ctx.view.w or 400
    local height = ctx.view.h or 56
    local waiting = {}
    for _, agent in roster(ctx) do
        if agent.s == "needs_input" then
            waiting[#waiting + 1] = agent
        end
    end
    local agent = waiting[1]
    if not agent then
        return ui.box{ w = width, h = height }
    end
    local session = text(agent.x)
    local title = harness(agent) .. (if session ~= "" then " in " .. session else "") .. " is asking for your help"
    local details = name(agent)
    local since = waited(ctx, agent)
    if since ~= "" then
        details ..= " · " .. since
    end
    if #waiting > 1 then
        details ..= " · +" .. tostring(#waiting - 1) .. " more waiting"
    end
    local textWidth = width - AVATAR_W * 2 - 14
    local lines = { gap = 2, center = false, w = textWidth,
        ui.text{ text = title, size = 13, weight = "semibold", color = TEXT, maxWidth = textWidth },
        ui.text{ text = details, size = 11, color = DIM, maxWidth = textWidth } }
    if text(agent.m) ~= "" then
        lines[#lines + 1] = ui.text{ text = agent.m, size = 11, color = FAINT, maxWidth = textWidth }
    end
    return ui.row{ key = "help", w = width, h = height, gap = 14,
        avatar(agent, 2, "help"),
        ui.column(lines) }
end

-- Where it is and how long for, for the details strip: "Claude in session-0 · working · 3m ago".
local function status(ctx, agent): string
    local parts = { harness(agent) .. (if text(agent.x) ~= "" then " in " .. agent.x else ""), label(agent) }
    local since = waited(ctx, agent)
    if since ~= "" then
        parts[#parts + 1] = since
    end
    return table.concat(parts, " · ")
end

-- A click on a desk or a critter shows its agent in the strip under the room; another hides it.
-- (Not on hover: a hover target inside the panel ends the island's own hover, which closes it.)
local function pickable(element, agent)
    element.onClick = function(next)
        next.state.officePick = if next.state.officePick == agent.i then nil else agent.i
        next.state.officeError = nil
    end
    return element
end

-- A name centred under something `width` points wide whose left edge is at `x`.
local function tag(ctx, key: string, value: string, x: number, width: number, color: string?)
    local measured = ctx.format.measure(value, { size = 9, weight = "medium" }) -- also returns the height
    local shown = math.min(width, measured)
    return ui.text{ key = key, text = value, size = 9, weight = "medium", color = color or DIM, maxWidth = width,
        align = "topLeading", dx = x + (width - shown) / 2, dy = GROUND * PIX + 3 }
end

local function critterAt(ctx, agent, mood: number, x: number, y: number, seated: boolean)
    return pickable(ui.shader{ key = "critter-" .. agent.i, source = AVATAR, w = AVATAR_W * PIX, h = AVATAR_H * PIX,
        fps = 12, align = "topLeading", dx = x * PIX, dy = y * PIX,
        values = { mood, phase(agent.i), if agent.h == "claude-code" then 1 else 0, if seated then 1 else 0 } }, agent)
end

local function office(ctx)
    local width = ctx.view.w or 664
    local height = (ctx.view.h or 170 + DETAILS_H) - DETAILS_H -- the room; the details strip goes under it
    local columns = math.floor(width / PIX)
    local agents = roster(ctx)
    -- Desks in pane order, so nobody changes desk when its state changes.
    local desks = table.clone(agents)
    table.sort(desks, function(a, b) return a.i < b.i end)
    local stations, lounge, coffee = { {}, {}, {} }, {}, nil
    local shown = 0
    for index, agent in desks do
        local state = AT_DESK[agent.s]
        local seated = index <= SEATS * #DESK_SLOTS
        if seated then
            local desk = stations[DESK_SLOTS[(index - 1) % #DESK_SLOTS + 1]]
            desk[#desk + 1] = { agent = agent, state = state or 3 }
        end
        if state ~= nil then
            shown += if seated then 1 else 0
        elseif finished(agent) and not coffee then
            coffee = agent
            shown += 1
        elseif #lounge < POUFS then
            lounge[#lounge + 1] = agent
            shown += 1
        end
    end
    local clock = ctx.format.date(ctx.data.seconds, "HH:mm") or ""
    local hour, minute = string.match(clock, "(%d+):(%d+)")
    local scene = { key = "office", w = width, h = height,
        ui.shader{ key = "room", source = ROOM, w = width, h = height, fps = 8,
            values = { (tonumber(hour) or 0) * 60 + (tonumber(minute) or 0), if coffee then 1 else 0, PIX, 0 } } }
    local from, to = DESKS_FROM, columns - DESKS_TO
    for slot, seats in stations do
        local count = math.max(1, #seats) -- a free desk still shows one empty seat
        local size = count * SEAT_W
        local column = if slot == 1 then from elseif slot == 3 then to - size else math.floor((from + to - size) / 2)
        for seat = 1, count do
            local station = seats[seat]
            local agent = station and station.agent
            local x = (column + (seat - 1) * SEAT_W) * PIX
            local ends = (if seat == 1 then 1 else 0) + (if seat == count then 2 else 0)
            -- A free seat is drawn like an agent's away one: empty chair, monitor asleep.
            local desk = ui.shader{ key = "desk-" .. slot .. "-" .. seat, source = DESK, w = SEAT_W * PIX,
                h = DESK_H * PIX, fps = 12, align = "topLeading", dx = x, dy = (GROUND - DESK_H) * PIX,
                values = if agent then { station.state, phase(agent.i), if agent.h == "claude-code" then 1 else 0, ends }
                    else { 3, slot, 0, ends } }
            scene[#scene + 1] = if agent then pickable(desk, agent) else desk
            if agent and station.state ~= 3 then
                scene[#scene + 1] = tag(ctx, "name-" .. agent.i, name(agent), x + 2, SEAT_W * PIX - 4,
                    if agent.s == "needs_input" then YELLOW elseif agent.s == "errored" then RED else nil)
            end
        end
    end
    if coffee then
        scene[#scene + 1] = critterAt(ctx, coffee, 5, 21, GROUND - AVATAR_H, false)
        scene[#scene + 1] = tag(ctx, "name-" .. coffee.i, name(coffee), 19 * PIX, 20 * PIX)
    end
    for index, agent in lounge do
        local center = columns - 67 + (index - 1) * 21
        scene[#scene + 1] = critterAt(ctx, agent, 3, center - AVATAR_W / 2, GROUND - 17, true)
        scene[#scene + 1] = tag(ctx, "name-" .. agent.i, name(agent), (center - 10) * PIX, 20 * PIX, FAINT)
    end
    local focus = nil
    for _, agent in agents do
        if agent.i == ctx.state.officePick then
            focus = agent
        end
    end
    -- Under the room: the clicked agent (who, where, since when, what it does) and Open, which
    -- shows its pane in TUIOS through the open.sh provider.
    local strip = { key = "details", w = width, h = DETAILS_H, gap = 10, pad = 10 }
    if focus then
        local where = if AT_DESK[focus.s] ~= nil then "at the desk"
            elseif focus == coffee then "on a coffee break" else "resting in the lounge"
        local textWidth = width - 2 * 10 - 10 - OPEN_W
        local nameWidth = math.min(textWidth / 2, (ctx.format.measure(name(focus), { size = 12, weight = "semibold" })))
        local failure = ctx.state.officeError
        local note = if failure then failure else text(focus.m)
        local lines = { gap = 2, center = false, w = textWidth,
            ui.row{ gap = 6,
                ui.text{ text = name(focus), size = 12, weight = "semibold", color = TEXT, maxWidth = nameWidth },
                ui.text{ text = status(ctx, focus) .. " · " .. where, size = 10, color = DIM,
                    maxWidth = textWidth - nameWidth - 6 } } }
        if note ~= "" then
            lines[#lines + 1] = ui.text{ text = note, size = 10, color = if failure then RED else FAINT,
                maxWidth = textWidth }
        end
        strip[#strip + 1] = ui.column(lines)
        strip[#strip + 1] = ui.box{ grow = 1 }
        strip[#strip + 1] = ui.stack{ key = "open", w = OPEN_W, h = 24, radius = 12, fill = "#FFFFFF1A",
            hover = "#FFFFFF33", pressScale = 0.95, help = "Show this pane in TUIOS",
            onClick = function(next)
                local _, err = omniwm.provider.send("open", { session = text(focus.x), pane = focus.i }, nil,
                    function(result)
                        next.state.officeError = if result.ok then nil else tostring(result.error)
                    end)
                next.state.officeError = err
            end,
            ui.row{ gap = 3,
                ui.text{ text = "Open", size = 11, weight = "semibold", color = TEXT },
                ui.symbol{ name = "arrow.up.right", size = 9, color = TEXT } } }
    elseif #agents > 0 then
        strip[#strip + 1] = ui.text{ key = "hint", text = "Click a Claude for details", size = 10, color = FAINT }
    end
    if #agents == 0 then
        scene[#scene + 1] = ui.text{ key = "empty", text = "No agents in TUIOS", size = 12, weight = "medium",
            color = DIM, align = "top", dy = 30 }
    elseif #agents > shown then
        scene[#scene + 1] = ui.text{ key = "more", text = "+" .. tostring(#agents - shown) .. " more", size = 10,
            weight = "semibold", color = DIM, align = "topTrailing", dx = -10, dy = 8 }
    end
    return ui.column{ key = "office-view", w = width, h = height + DETAILS_H, gap = 0, ui.stack(scene), ui.row(strip) }
end

return {
    views = { troupe = troupe, help = help, office = office },
}
