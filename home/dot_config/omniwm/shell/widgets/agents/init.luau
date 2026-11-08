-- The agents in every TUIOS session (Claude Code and the rest): how many are working,
-- yellow when one waits for you, red when one errored, nothing when there are none.
-- TUIOS's hooks push them with ~/Library/Application Support/tuios/agents.sh, as
-- `omniwmctl shell trigger agents update "<working> <state>"`. Until the first push
-- after OmniWM starts (at most the dock's 10s poll) the widget stays empty.
local look = require("../lib/look")

local colors = { needs_input = "warning", errored = "error" }

function trigger(ctx, event)
    if event.name == "update" then
        ctx.state.agents = event.value
    end
end

function render(ctx)
    local working, state = string.match(ctx.state.agents or "", "^(%d+) (%S+)$")
    if not working then
        return ui.box{ w = 0, h = 0 }
    end
    local scale = look.scale(ctx)
    return look.bar(ctx, {
        look.text{ text = "✻ " .. working, size = 13 * scale, weight = "medium",
            color = colors[state] or "secondaryForeground" },
    })
end
