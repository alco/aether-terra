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

function makeOperator(typ)
    return { type = "operator", value = typ }
end

function makeTerminal(typ)
    return { type = "term", value = typ }
end

function makeNewline()
    return { type = "nl", value = "" }
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
    local s, e = str:find(ident_pat, pos)
    if s == nil then
        error("Bad identifier", 0)
    else
        pos = e+1
    end

    return makeIdentifier(str:sub(s, e)), pos
end

function parseAtom(str, pos)
    pos = pos or 1
    local s, e = str:find(":"..ident_pat, pos)
    if s == nil then
        error("Bad atom", 0)
    else
        pos = e+1
    end

    return makeAtom(str:sub(s, e)), pos
end

function parseNewline(str, pos)
    pos = pos or 1
    local s, e = str:find("\n+", pos)
    if s == nil then
        error("Expected newline", 0)
    else
        pos = e+1
    end

    return makeNewline(), pos
end

function tokenize(str)
    local tokens = {}
    local pos = 1
    local ops = {"--", "++", "->", "==", "!=", "<=", ">=", "+", "-", "*", "/", "^", "<", ">", "=", "!"}
    local terminals = {"'", "`", "::", "(", ")", "[", "]", "{", "}", ".", ",", ":"}
    local whitespace = {" ", ",", "\t"}
    local tok
    local stat
    local first

    local function match_tok(toks, str)
        for i, tok in ipairs(toks) do
            if str == tok then return tok end
        end
    end

    while pos <= str:len() do
        first = str:sub(pos, pos)
        if first:match("[0-9]") or (str:sub(pos,pos+1)):match("-[0-9]") then
            tok, pos = parseNumber(str, pos)
        -- elseif first:match(":") then
        --     tok, pos = parseAtom(str, pos)
        elseif pos <= str:len()-1 and match_tok(ops, str:sub(pos, pos+1)) then
            op = str:sub(pos, pos+1)
            tok = makeOperator(op)
            pos = pos + 2
        elseif match_tok(ops, first) then
            tok = makeOperator(first)
            pos = pos + 1
        elseif first:match("\n") then
            tok, pos = parseNewline(str, pos)
        elseif pos <= str:len()-1 and match_tok(terminals, str:sub(pos, pos+1)) then
            tok = makeTerminal(str:sub(pos, pos+1))
            pos = pos + 2
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

function printoken(tok)
    local str = tok.type
    if tok.value then
        str = str.." : "..tok.value
    end
    --table_print(tok)
    print(str)
end

function printokens(tokens)
    for i,t in ipairs(tokens) do
        printoken(t)
    end
end

-- this is a coroutine continuosly yielding a stream of tokens
function get_token()
    while true do
        local line = aether_readline()
        if line == nil then
            -- EOF
            return
        end
        
        local toks = tokenize(line)
        --table_print(toks)
        for i,t in ipairs(toks) do
            coroutine.yield(t)
        end
    end
end

get_tok_co = coroutine.wrap(get_token)

require("parser")

function doexpr()
    --if _token == nil then
        --startParser()
    --end

    local result = expression()
    --table_print(result)
    --local tok
    --for i = 1, 3 do
    --    tok = get_tok_co()
    --    if tok == nil then
    --        return -1  -- signal EOF
    --    end
    --    printoken(tok)
    --end
    return 3
end
