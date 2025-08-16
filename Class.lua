-- class template --

---------------------------------------------------------------------------------------------------------------------------
local Class = {}

local function extend(_, parent)
    local c = {}

    if parent then
        setmetatable(c, {__index = parent})
    end

    function c:init(...)
        error("new object function not implemented")
    end

    function c:new(...)
        local o = {}
        setmetatable(o, {__index = c})
        o:init(...)
        return o
    end

    return c
end

setmetatable(Class, {__call = extend})

return Class