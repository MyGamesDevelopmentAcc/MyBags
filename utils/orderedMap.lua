OrderedMap = {}
OrderedMap.__index = OrderedMap

function OrderedMap:new()
    local instance = {
        _keys = {}, -- to store the order of keys
        _values = {} -- to store the key-value pairs
    }
    setmetatable(instance, OrderedMap)
    return instance
end

function OrderedMap:set(key, value)
    if self._values[key] == nil then
        table.insert(self._keys, key) -- only add key to order list if it's new
    end
    self._values[key] = value
end

function OrderedMap:get(key)
    return self._values[key]
end

function OrderedMap:delete(key)
    if self._values[key] ~= nil then
        self._values[key] = nil
        for i, k in ipairs(self._keys) do
            if k == key then
                table.remove(self._keys, i)
                break
            end
        end
    end
end

function OrderedMap:keys()
    return self._keys
end

function OrderedMap:iterate()
    local i = 0
    local n = #self._keys
    return function()
        i = i + 1
        if i <= n then
            local key = self._keys[i]
            return key, self._values[key]
        end
    end
end

function OrderedMap:reorder(new_order)
    local new_keys = {}
    for _, key in ipairs(new_order) do
        if self._values[key] ~= nil then
            table.insert(new_keys, key)
        else
            error("Key '" .. key .. "' does not exist in the map")
        end
    end
    self._keys = new_keys
end