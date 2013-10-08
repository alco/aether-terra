-------------------------------
-- *** Utility functions *** --
-------------------------------

local M = {}

function M.error(str)
    error(str, 0)
end

function M.max(a, b)
    return math.max(a, b)
end

function M.pack(...)
  return { n = select("#", ...), ... }
end

function M.map(list, fn)
    local new_list = {}
    for _, v in ipairs(list) do
        table.insert(new_list, fn(v))
    end
    return new_list
end

function M.map_format(list)
    return M.map(list, function(elem)
        return elem:format()
    end)
end

function M.strjoin(list, sep)
    sep = sep or " "

    local str = ""
    for i, v in ipairs(list) do
        str = str..v
        if i < #list then
            str = str..sep
        end
    end
    return str
end

function M.strsplit(str, sep)
    local sep, fields = sep or "%s", {}
    local pattern = "([^"..sep.."]+)"
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function M.strformat(fmt, ...)
    local str = fmt
    local args = M.pack(...)
    for i = 1, args.n do
        str = str:gsub("{"..i.."}", args[i])
    end
    return str
end

function M.strtrim(str)
    return str:match("^%s*(.-)%s*$")
end

return M
