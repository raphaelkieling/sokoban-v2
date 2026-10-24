local Component = require("src.core.Component")

-- Marks an interactive object that can be connected to and moved by the Puppeteer.
local Tetherable = Component:extend()
Tetherable.componentName = "Tetherable"

function Tetherable:init()
	Component.init(self)
end

return Tetherable
