function makeAtom(value)
    return { type = "atom", value = value }
end

function makeLiteralInt(value)
    return { type = "int", value = value }
end

function makeLiteralFloat(value)
    return { type = "float", value = value }
end

function makeIdentifier(name)
    return { type = "ident", value = name }
end

function makeTerminal(typ)
    return { type = typ, value = typ }
end


-- "-?\d+(.\d*)?([eE][-+]\d+)?([a-zA-Z]\w*)?"
function parseNumber(str, pos)
    pos = pos or 1
    local typ = "int"
    local result = ""

    local s, e = str:find("-?%d+", pos)
    result = result .. str:sub(s, e)

    pos = e+1

    --print("|||")
    --print("Current pos = "..pos)
    --print("Leftover string = "..str:sub(pos))
    
    if str:sub(pos, pos) == "." then
        typ = "float"
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
        typ = "float"
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

    if typ == "int" then
        return makeLiteralInt(result), pos
    elseif typ == "float" then
        return makeLiteralFloat(result), pos
    else
        error("Undefined number type", 0)
    end
end

ident_pat = "[^%s'`,()]+"

function parseIdentifier(str, pos)
    pos = pos or 1
    s, e = str:find(ident_pat, pos)
    if s == nil then
        error("Bad identifier", 0)
    else
        pos = e+1
    end

    return makeIdentifier(str:sub(s, e)), pos
end

function parseAtom(str, pos)
    pos = pos or 1
    s, e = str:find(":"..ident_pat, pos)
    if s == nil then
        error("Bad atom", 0)
    else
        pos = e+1
    end

    return makeAtom(str:sub(s, e)), pos
end

function match_tok(toks, str)
    for i, tok in ipairs(toks) do
        if str == tok then return tok end
    end
end

function tokenize(str)
    local tokens = {}
    local pos = 1
    local terminals = {"'", "`", "(", ")"}
    local whitespace = {" ", ",", "\t", "\n"}
    local tok

    while pos <= str:len() do
        first = str:sub(pos, pos)
        if first:match("[0-9]") or (str:sub(pos,pos+2)):match("-[0-9]") then
            tok, pos = parseNumber(str, pos)
        elseif first:match(":") then
            tok, pos = parseAtom(str, pos)
        elseif match_tok(terminals, first) then
            tok = makeTerminal(first)
            pos = pos + 1
        elseif match_tok(whitespace, first) then
            pos = pos + 1
            tok = nil
        else
            stat, tok, pos = pcall(parseIdentifier, str, pos)
            if not stat then
                error("Undefined token "..first)
            end
        end
        if tok then
            table.insert(tokens, tok)
        end
    end
    return tokens
end

function printokens(tokens)
    for i,t in ipairs(tokens) do
        print(t.type .. ":" .. t.value)
    end
end

------------------------------------

function startParser(tokens)
    _tokenPos = 1
    _token = nil
    _tokens = tokens

    nextToken()
end

function nextToken()
    local tok = _token
    _token = _tokens[_tokenPos]
    _tokenPos = _tokenPos + 1
    return tok
end

function peek()
    return _tokens[_tokenPos]
end

function advance(typ)
    if typ then expect(typ) end
    local tok = _token
    nextToken()
    return tok
end

function expect(typ)
    if _token.type ~= typ then
        error("Unexpected token ".._token.type.."; expected "..typ)
    end
end

input = io.read("*all")
tokens = tokenize(input)

startParser(tokens)

function parseExpr()
    if _token.type == "(" then
        advance("(")
        local funcall = { type = "list", args = {} }
        while _token.type ~= ")" do
            table.insert(funcall.args, parseExpr())
        end
        advance(")")
        return funcall
    elseif _token.type == "'" then
        advance("'")
        local quote = { type = "quote", expr = parseExpr() }
        return quote
    else
        local tok = nextToken()
        if tok == nil then
            print("The end")
        else
            return tok
        end
    end
end

function lookup(ident, env)
    local val = env.names[ident]
    if val == nil then
        if env.parent then
            return lookup(ident, env.parent)
        else
            error("Undefined identifier "..ident)
        end
    end
    return val
end

function evalExpr(expr, env, lkp, shouldCallFns)
    local lookup = lkp or lookup
    local callFns
    if shouldCallFns == nil then
        callFns = true
    else
        callFns = shouldCallFns
    end
    if expr.type == "list" then
        if #expr.args == 0 then
            return nil
        else
            local fun = expr.args[1]
            if fun.type ~= "ident" then
                fun = evalExpr(fun, env, lkp, shouldCallFns)
                if callFns and type(fun) ~= "function" then
                    error("Bad funcall: "..expr.args[1].type)
                end
            end

            local func = lookup(fun.value, env)
            local args = {}

            -- Handle special forms first
            if fun.value == "def" then
                if #expr.args ~= 3 then
                    error("Bad arity for def")
                end
                return func(expr.args[2], expr.args[3])
            elseif fun.value == "fn" then
                return func(expr.args[2], expr.args[3])
            else
                for i = 2, #expr.args do
                    args[i-1] = evalExpr(expr.args[i], env)
                end
                return func(unpack(args))
            end
        end
    elseif expr.type == "quote" then
        return expr.expr
    elseif expr.type == "ident" then
        return lookup(expr.value, env)
    elseif expr.type == "atom" then
        return expr.value
    elseif expr.type == "int" then
        return expr.value
    elseif expr.type == "float" then
        return expr.value
    end
end

-- Print anything - including nested tables
function table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    for key, value in pairs (tt) do
      io.write(string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        io.write(string.format("[%s] => table\n", tostring (key)));
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write("(\n");
        table_print (value, indent + 7, done)
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write(")\n");
      else
        io.write(string.format("[%s] => %s\n",
            tostring (key), tostring(value)))
      end
    end
  else
    io.write(tt .. "\n")
  end
end

function add(...) 
    local len = select("#", ...)
    if len == 0 then
        return 0
    end
    local acc = select(1, ...)
    for i = 2, len do
        acc = acc + select(i, ...)
    end
    return acc
end

function sub(...) 
    local len = select("#", ...)
    if len < 1 then
        error("Bad arity for -")
    end
    local acc = -select(1, ...)
    for i = 2, len do
        acc = acc - select(i, ...)
    end
    return acc
end

function mul(...) 
    local len = select("#", ...)
    if len == 0 then
        return 1
    end
    local acc = select(1, ...)
    for i = 2, len do
        acc = acc * select(i, ...)
    end
    return acc
end

function div(...) 
    local len = select("#", ...)
    if len < 1 then
        error("Bad arity for /")
    elseif len == 1 then
        return 1 / select(1, ...)
    end
    local acc = select(1, ...)
    for i = 2, len do
        acc = acc / select(i, ...)
    end
    return acc
end

env = { 
    parent = nil,
    names = {
        ["+"] = add, 
        ["-"] = sub,
        ["*"] = mul, 
        ["/"] = div,
    }
}

function def(ident, expr)
    local val = evalExpr(expr, env)
    env.names[ident.value] = val
    return nil
end
env.names.def = def

function fn(args, expr)
    local names = {}
    for i = 1, #args do
        names[args[i].value] = true
    end

    local function modified_lookup(ident, env)
        if names[ident.value] then
            return ident
        else
            stat, val = pcall(lookup(ident, env))
            if stat then
                return ident
            else
                error(val)
            end
        end
    end

    expr = evalExpr(expr, fn_env, modified_lookup)
end
env.names.fn = fn

printokens(tokens)
print("------------")

while _token do
    result = parseExpr()
    --table_print(result, 2)
    print(evalExpr(result, env))
end
