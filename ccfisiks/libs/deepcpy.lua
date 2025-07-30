local function deepcpy(t)
    if type(t) == 'table' then
        local new = {}
        for k,v in pairs(t) do
            new[k] = deepcpy(v)
        end
        setmetatable(new,getmetatable(t))
        return new
    else
        return t
    end
end

return deepcpy