-- Spaces: the apps in each workspace, shown by the notch on hover. spaces.py follows
-- OmniWM's workspace-bar feed (kept while the bar is off) into the "spaces" topic.
-- A tile per workspace with apps (and the focused one): a click goes there; each icon
-- shows OmniWM's window preview on hover and focuses its window on click.

local TEXT = "#F5F5F7"
local DIM = "#FFFFFF99"
local ICON = 18
local SLOT = ICON + 4
local GAP = 6
local PAD = 8

local function strip(ctx)
    local width = ctx.view.w or 420
    local height = ctx.view.h or 40
    local provider = ctx.instance and ctx.instance.provider
    local spaces = provider and provider.state.spaces
    if type(spaces) ~= "table" then
        local waiting = provider and provider.status == "not_approved"
        return ui.row{ key = "spaces-wait", w = width, h = height,
            ui.text{ text = if waiting then "Allow the Workspace apps program in OmniWM to see your apps"
                else "Loading workspaces…", size = 11, color = DIM, maxWidth = width } }
    end
    local tiles = {}
    for _, workspace in ctx.data.workspaces or {} do
        local apps = if type(spaces[workspace.id]) == "table" then spaces[workspace.id] else {}
        if #apps > 0 or workspace.focused then
            tiles[#tiles + 1] = { workspace = workspace, apps = apps }
        end
    end
    local row = { key = "spaces", w = width, h = height, gap = GAP }
    if #tiles == 0 then
        return ui.row(row)
    end
    local tileWidth = (width - GAP * (#tiles - 1)) / #tiles
    for _, tile in tiles do
        local workspace, apps = tile.workspace, tile.apps
        local label = ctx.format.measure(workspace.name, { size = 12, weight = "semibold" })
        local fits = math.max(1, math.floor((tileWidth - 2 * PAD - label - GAP) / SLOT))
        local shown = if #apps > fits then fits - 1 else #apps
        local natural = 2 * PAD + label + (if #apps > 0 then GAP + math.max(1, #apps) * SLOT else 0)
        local content = { gap = GAP,
            ui.text{ text = workspace.name, size = 12, weight = "semibold",
                color = if workspace.focused then TEXT else DIM } }
        local icons = { gap = 0 }
        for index = 1, shown do
            local app = apps[index]
            icons[#icons + 1] = ui.stack{ key = app.i, w = SLOT, h = SLOT, radius = 5, hover = "#FFFFFF24",
                target = "window " .. app.i, preview = true, onClick = "window focus " .. app.i,
                help = app.a .. (if (tonumber(app.c) or 1) > 1 then " (" .. tostring(app.c) .. " windows)" else ""),
                ui.icon{ app = app.b, w = ICON, h = ICON, placeholder = "app.dashed",
                    opacity = if app.f or workspace.focused then 1 else 0.85 } }
        end
        if #apps > shown then
            icons[#icons + 1] = ui.text{ text = "+" .. tostring(#apps - shown), size = 10, weight = "semibold",
                color = DIM }
        end
        if #icons > 0 then
            content[#content + 1] = ui.row(icons)
        end
        row[#row + 1] = ui.stack{ key = "ws-" .. workspace.id, w = math.min(tileWidth, natural), h = height,
            radius = 10, fill = if workspace.focused then "#FFFFFF26" else "#FFFFFF12", hover = "#FFFFFF33",
            onClick = "workspace focus-name " .. workspace.id, help = "Go to workspace " .. workspace.name,
            ui.row(content) }
    end
    return ui.row(row)
end

return {
    views = { strip = strip },
}
