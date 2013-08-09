function makeLiteralToken(tok, value)
    return { type = tok, value = value }
end

function makeIdentifier(name)
    return { type = "identifier", name = name }
end

function makeOperator(typ)
    return { type = "operator", token = typ }
end

-- "\d+(.\d*)?([eE][-+]\d+)?([a-zA-Z]\w*)?"
function parseNumber(str, pos)
    pos = pos or 1
    local typ = "int"
    local result = ""

    local s, e = str:find("%d+", pos)
    result = result .. str:sub(s, e)

    pos = e+1

    --print("|||")
    --print("Current pos = "..pos)
    --print("Leftover string = "..str:sub(pos))
    
    if str:sub(pos, pos) == "." then
        typ = "flt"
        result = result .. "."

        s, e = str:find("%d+", pos+1)
        if s == pos+1 then
            result = result .. str:sub(s, e)
            pos = e+1
        else
            pos = pos+1
        end
    end

    --print("---")
    --print("Current pos = "..pos)
    --print("Leftover string = "..str:sub(pos))

    if str:sub(pos, pos) == "e" or str:sub(pos, pos) == "E" then
        typ = "flt"
        result = result .. "e"

        s, e = str:find("[+-]?%d+", pos+1)
        if s == pos+1 then
            result = result .. str:sub(s, e)
            pos = e+1
        else
            error("Malformed number", 0)
        end
    end

    --print("***")
    --print("Current pos = "..pos)
    --print("Leftover string = "..str:sub(pos))

    s, e = str:find("[%a_][%w_]*", pos)
    --if s ~= nil then
        --print("Found '"..str:sub(s,e).."' at "..s)
    --end

    if s == pos then
        typ = str:sub(s, e)
        pos = e+1
    end

    return makeLiteralToken(typ, result), pos
end

function parseIdentifier(str, pos)
    s, e = str:find("[_%a][_%a%d]*", pos)
    if s == nil then
        error("Bad identifier", 0)
    else
        pos = e+1
    end

    return makeIdentifier(str:sub(s, e)), pos
end


function match_op(ops, str)
    for i, op in ipairs(ops) do
        if str == op then return op end
    end
end

function tokenize(str)
    local tokens = {}
    local pos = 1
    local ops = {"--", "++", "->", "==", "!=", "<=", ">="}
    while pos <= str:len() do
        first = str:sub(pos, pos)
        if first:match("[0-9]") then
            tok, pos = parseNumber(str, pos)
        elseif first:match("[_a-zA-Z]") then
            tok, pos = parseIdentifier(str, pos)
        elseif pos <= str:len()-1 and match_op(ops, str:sub(pos, pos+1)) then
            op = match_op(ops, str:sub(pos, pos+1))
            tok = makeOperator(op)
            pos = pos + 2
        elseif first:match("[%+%-%*/%^<>=!]") then
            tok = makeOperator(first)
            pos = pos + 1
        elseif first:match(" ") then
            pos = pos + 1
            tok = nil
        else
            error("Undefined token")
        end
        if tok then
            table.insert(tokens, tok)
        end
    end
    return tokens
end

function printokens(tokens)
    for i,t in ipairs(tokens) do
        output = t.type .. ":"
        if t.type == "identifier" then
            output = output .. t.name
        elseif t.type == "operator" then
            output = output .. t.token
        else
            output = output .. t.value
        end
        print(output)
    end
end

n = parseNumber("123")
assert(n.value == "123" and n.type == "int")

n = parseNumber("123.")
assert(n.value == "123." and n.type == "flt")

n = parseNumber("123.45")
assert(n.value == "123.45" and n.type == "flt")

n = parseNumber("123.45")
assert(n.value == "123.45" and n.type == "flt")

n = parseNumber("123e10")
assert(n.value == "123e10" and n.type == "flt")

n = parseNumber("123E+10")
assert(n.value == "123e+10" and n.type == "flt")

n = parseNumber("123E-10")
assert(n.value == "123e-10" and n.type == "flt")

n = parseNumber("123.f")
assert(n.value == "123." and n.type == "f")

n = parseNumber("123. f")
assert(n.value == "123." and n.type == "flt")

n = parseNumber("123uint32")
assert(n.value == "123" and n.type == "uint32")

n = parseNumber("123.45E-10")
assert(n.value == "123.45e-10" and n.type == "flt")

n = parseNumber("123 .45E-10")
assert(n.value == "123" and n.type == "int")

n = parseNumber("123 abc")
assert(n.value == "123" and n.type == "int")

n = parseNumber("123_abc_d")
assert(n.value == "123" and n.type == "_abc_d")

n = parseNumber("123 4 abc_d")
assert(n.value == "123" and n.type == "int")

n = parseNumber("123 4.f abc_d")
assert(n.value == "123" and n.type == "int")

n = parseNumber("4.f abc_d")
assert(n.value == "4." and n.type == "f")

n = parseNumber("4.f 5a")
assert(n.value == "4." and n.type == "f")

status, err = pcall(parseNumber, "123.45E")
assert(status == false and err == "Malformed number")

printokens(tokenize("4.f 5a"))
