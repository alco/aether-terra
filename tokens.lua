function makeAtom(value)
    return { type = "atom", value = value }
end

function makeLiteralInt(value)
    return { type = "int", value = value }
end

function makeLiteralFloat(value)
    return { type = "float", value = value }
end

function makeLiteralString(value)
    return { type = "string", value = value }
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

ident_pat = "[_%w][_%w0-9]*"

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

-- def escape(char):
--     assert len(char) == 1
--     if char == "n":
--         return "\n"
--     elif char == "t":
--         return "\t"
--     elif char == "\\":
--         return "\\"
--     elif char == "\"":
--         return "\""
--     raise TokenizerError("Unhandled escape sequence %s" % char)
-- 
-- def extract_string(program, pos):
--     """Scan through the string until a closing quote is found"""
--     string = ""
--     escaping = False
--     while pos < len(program):
--         if program[pos] == '\\' and not escaping:
--             escaping = True
--         elif escaping:
--             string += escape(program[pos])
--             escaping = False
--         elif program[pos] == '"':
--             break
--         else:
--             string += program[pos]
--         pos += 1
--     # end while
--     if pos == len(program):
--         raise TokenizerError("Reached end of input when looking for a closing quote")
--     pos += 1
--     return string, pos

function escape(char)
    if char == "n" then
        return "\n"
    elseif char == "t" then
        return "\t"
    elseif char == "\\" then
        return "\\"
    elseif char == "\"" then
        return "\""
    end
    error("Unhandled escaped sequence "..char)
end

function parseString(str, pos)
    pos = pos or 1
    -- skip initial quote
    pos = pos + 1
    local result = ""
    local escaping = false
    while pos <= str:len() do
        local char = str:sub(pos, pos)
        if char == "\\" and not escaping then
            escaping = true
        elseif escaping then
            result = result .. escape(char)
            escaping = false
        elseif char == "\"" then
            break
        else
            result = result .. char
        end
        pos = pos + 1
    end
    if pos > str:len() then
        error("Reached end of input while looking for a closing quote")
    end
    return makeLiteralString(result), pos + 1
end

function tokenize(str)
    local tokens = {}
    local pos = 1
    local ops = {"--", "++", "->", "==", "≠", "≤", "≥", "↑", "**", "•", "+", "-", "*", "/", "^", "<", ">", "=", "!", ":"}
    local terminals = {"'", "`", "::", "(", ")", "[", "]", "{", "}", ".", ";"}
    local whitespace = {" ", ",", "\t", "\n"}
    local tok
    local stat
    local first
    local op

    local function match_tok(toks, str)
        for i, tok in ipairs(toks) do
            if str == tok then return tok end
        end
    end

    while pos <= str:len() do
        first = str:sub(pos, pos)
        if first:match("[0-9]") then
            tok, pos = parseNumber(str, pos)
        -- elseif first:match(":") then
        --     tok, pos = parseAtom(str, pos)
        elseif pos <= str:len()-2 and match_tok(ops, str:sub(pos, pos+2)) then
            op = str:sub(pos, pos+2)
            tok = makeOperator(op)
            pos = pos + 3
        elseif pos <= str:len()-1 and match_tok(ops, str:sub(pos, pos+1)) then
            op = str:sub(pos, pos+1)
            tok = makeOperator(op)
            pos = pos + 2
        elseif match_tok(ops, first) then
            tok = makeOperator(first)
            pos = pos + 1
        --elseif first:match("\n") then
            --tok, pos = parseNewline(str, pos)
        elseif first == "\"" then
            tok, pos = parseString(str, pos)
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
            --print("got token")
            --table_print(tok)
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
function get_token_fn(line)
    return function(opt)
        while true do
            --print("tokenizing line")
            local toks = tokenize(line)
            --print("did end tokenizing line")
            for i,t in ipairs(toks) do
                opt = coroutine.yield(t)
            end
            --print("no toks")
            --table_print(opt)

            while opt and opt.async do
                opt = coroutine.yield(nil)
            end
            
            line = aether_readline()
            if line == nil then
                -- EOF
                return
            end
        end
    end
end

get_tok_co = nil

function make_tok_co(line)
    return coroutine.wrap(get_token_fn(line))
end

require("parser")

function doexpr(line)
    -- Create a token stream just for this invocation of doexpr()
    get_tok_co = make_tok_co(line)

    resetParser()

    --print("Started with line '"..line.."'")

    local exprs = {}

    while peekParseNode() and peekParseNode().id == ";" do
        skip(";")
    end

    while peekParseNode() do
        local result = expression()

        if peekParseNode() and peekParseNode().id == ";" then
            while peekParseNode() and peekParseNode().id == ";" do
                skip(";")
            end
        else
            -- Make sure there are no left-over tokens
            expect(nil)
        end

        table.insert(exprs, result)
    end

    --print("Result node:")
    --table_print(exprs)

    local last_result = nil
    for _, expr in ipairs(exprs) do
        -- >>> typecheck <<<
        -- >>> evaluate <<<
        last_result = expr
    end

    if last_result then
        print(pretty_print(last_result))
    --else
        --print("no tokens")
    end

    return 3
end
