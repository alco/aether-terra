-- "\d+(.\d*)?([eE][-+]\d+)?([a-zA-Z]\w*)?"
function parseNumber(str, pos)
    pos = pos or 1
    local typ = "int"
    local result = ""
    local s, e = str:find("%d+", pos)
    result = result .. str:sub(s, e)

    pos = e+1

    if str:sub(pos, pos) == "." then
        typ = "flt"
        result = result .. "."

        s, e = str:find("%d+", pos+1)
        if s ~= nil then
            result = result .. str:sub(s, e)
            pos = e+1
        else
            pos = pos+1
        end
    end

    if str:sub(pos, pos) == "e" or str:sub(pos, pos) == "E" then
        typ = "flt"
        result = result .. "e"

        s, e = str:find("[+-]?%d+", pos+1)
        if s ~= nil then
            result = result .. str:sub(s, e)
            pos = e+1
        else
            error("Malformed number", 0)
        end
    end

    s, e = str:find("%a%w*", pos)
    if s ~= nil then
        typ = str:sub(s, e)
    end

    return result, typ
end

n, t = parseNumber("123")
assert(n == "123" and t == "int")

n, t = parseNumber("123.")
assert(n == "123." and t == "flt")

n, t = parseNumber("123.45")
assert(n == "123.45" and t == "flt")

n, t = parseNumber("123.45")
assert(n == "123.45" and t == "flt")

n, t = parseNumber("123e10")
assert(n == "123e10" and t == "flt")

n, t = parseNumber("123E+10")
assert(n == "123e+10" and t == "flt")

n, t = parseNumber("123E-10")
assert(n == "123e-10" and t == "flt")

n, t = parseNumber("123.f")
assert(n == "123." and t == "f")

n, t = parseNumber("123uint32")
assert(n == "123" and t == "uint32")

n, t = parseNumber("123.45E-10")
assert(n == "123.45e-10" and t == "flt")

status, err = pcall(parseNumber, "123.45E")
assert(status == false and err == "Malformed number")

