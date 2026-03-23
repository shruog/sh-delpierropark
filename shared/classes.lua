--[[
    LunaPark - Shared OO class helpers
    Simple Lua OOP via metatables
]]

---@class Class
---@param base? table
function Class(base)
    local cls = {}
    cls.__index = cls
    if base then
        setmetatable(cls, { __index = base })
    end
    function cls:new(...)
        local instance = setmetatable({}, cls)
        if instance.init then
            instance:init(...)
        end
        return instance
    end
    return cls
end
