local cjson = require('cjson')

local json = {}
json.stringify = function(value, state)
    if (type(value) == 'table') and (next(value) == nil) then
        return "[]";
    end

    local status, ret = pcall(cjson.encode, value)
    if (status) then
        return ret
    end

    --print("encode", status, ret) 
    return nil, ret
end


json.parse = function(data)
    local status, ret = pcall(cjson.decode, data)
    if (status) then
        return ret
    end

    --print("decode", status, ret)
    return nil, ret
end

json.encode = json.stringify
json.decode = json.parse

return json
