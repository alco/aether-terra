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
    local ops = {"--", "++", "->", "==", "≠", "≤", "≥", "↑", "∞", "**", "•", "+", "-", "*", "/", "^", "<", ">", "=", "!", ":"}
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
        local typed_ast, action = typecheck(expr)
        if not typed_ast then
            error("Typecheck failed for expr: "..pretty_print(expr))
        end

        --if typed_ast.valtype then
            --print("Typed root type = "..typed_ast.valtype)
        --end

        -- >>> evaluate <<<
        local code = terra()
            return [gencode(typed_ast)]
        end

        if action then
            -- macro call
            if action == "disas" then
                code:disas()
            elseif action == "pretty" then
                code:printpretty()
            elseif action == "all" then
                code:printpretty()
                code:disas()
            end
            break
        end
        --code:printpretty()
        --code:disas()
        --print("---")
        local st_fn
        if typed_ast.valtype == "int" then
            st_fn = Cae.store_int
        elseif typed_ast.valtype == "float" then
            st_fn = Cae.store_float
        elseif typed_ast.valtype == "string" then
            st_fn = Cae.store_string
        end
        (terra() st_fn("_", code()) end)()
    end

    (terra() Cae.print_result() end)()

    return 1
end

Cae   = terralib.includec("ae_runtime.h")
Cmath = terralib.includec("math.h")
Cstd  = terralib.includec("stdlib.h")
Cstr  = terralib.includec("string.h")

terra ipow(a: int, n: int): int
    if n == 0 then
        return 1
    elseif n == 1 then
        return a
    elseif (n and 1) == 0 then
        var tmp = ipow(a, n >> 1)
        return tmp * tmp
    else
        return a * ipow(a, n-1)
    end
end

ae_env = {
    sin = {
        impls = {
            float = {
                impl = Cmath.sinf,
                valtype = "float",
                sig = {"float"}
            },
            double = {
                impl = Cmath.sin,
                valtype = "double",
                sig = {"double"}
            }
        },
        nargs = 1
    },
    ["+"] = {
        impls = {
            int = {
                impl = terra(a: int, b: int) return a + b end,
                valtype = "int",
                sig = {"int", "int"}
            },
            float = {
                impl = terra(a: float, b: float) return a + b end,
                valtype = "float",
                sig = {"float", "float"}
            }
        },
        nargs = 2
    },
    ["-"] = {
        impls = {
            int = {
                impl = terra(a: int, b: int) return a - b end,
                valtype = "int",
                sig = {"int", "int"}
            },
            float = {
                impl = terra(a: float, b: float) return a - b end,
                valtype = "float",
                sig = {"float", "float"}
            }
        },
        nargs = 2
    },
    ["**"] = {
        impls = {
            int = {
                impl = ipow,
                valtype = "int",
                sig = {"int", "int"}
            },
            float = {
                impl = Cmath.powf,
                valtype = "float",
                sig = {"float", "float"}
            }
        },
        nargs = 2
    },
    ["minus"] = {
        impls = {
            int = {
                impl = terra(a: int) return -a end,
                valtype = "int",
                sig = {"int"}
            },
            float = {
                impl = terra(a: float) return -a end,
                valtype = "float",
                sig = {"float"}
            }
        },
        nargs = 1
    },
    ["="] = {
        impls = {
            int = {
                impl = Cae.store_int,
                valtype = "int",
                sig = {"string", "int"}
            },
            float = {
                impl = Cae.store_float,
                valtype = "float",
                sig = {"string", "float"}
            },
            string = {
                impl = Cae.store_string,
                valtype = "string",
                sig = {"string", "string"}
            }
        },
        nargs = 2
    },

    -- Builtin macros
    pras = "macro"
}

extract_var = {
    int = Cae.get_int,
    float = Cae.get_float
    --string = Cae.take_string
}

function get_value_type(val)
    local ti = (terra(val: &Cae.value_t)
        if Cae.is_int(val) then
            return 1
        elseif Cae.is_float(val) then
            return 2
        elseif Cae.is_string(val) then
            return 3
        end
    end)(val)
    return ({"int", "float", "string"})[ti]
end

function typecheck(expr)
    if expr.valtype then
        -- must be a literal
        local value
        if expr.type == "int" or expr.type == "float" then
            value = tonumber(expr.value)
        elseif expr.type == "string" then
            value = expr.value
        else
            error("Unrecognized literal: "..pretty_print(expr))
        end
        return {
            type = expr.type,
            valtype = expr.valtype,
            value = value
        }
    elseif expr.type == "ident" then
        if ae_vars[expr.value] then
            return {
                type = "ident_var",
                valtype = get_value_type(ae_vars[expr.value]), --ae_vars[expr.value].valtype,
                value = expr.value
            }
        elseif ae_env[expr.value] then
            local typ
            if ae_env[expr.value] == "macro" then
                typ = "ident_macro"
            else
                typ = "ident_fun"
            end
            return {
                type = typ,
                --valtype = ae_env[expr.value].valtype,
                --sig = ae_env[expr.value].sig,
                value = expr.value
            }
        elseif expr.value == "prpr" or expr.value == "pras" or expr.value == "prall" then
            return {
                type = "ident_fun",
                valtype = "...",
                sig = "...",
                value = expr.value
            }
        end
    elseif expr.id == "funcall" then
        --table_print(expr)

        local typed_fn = typecheck(expr.name)
        if typed_fn.type == "ident_macro" then
            --table_print(expr)
            if expr.name.value == "pras" then
                return typecheck(expr.args[1]), "disas"
                --local code = terra()
                    --return [gencode(expr.args[1])]
                --end
                --code:disas()
                --return 0
            end
        end

        if typed_fn.type ~= "ident_fun" then
            error("Bad function in funcall: "..pretty_print(expr))
        end

        local fn = ae_env[typed_fn.value]
        if fn.nargs ~= #expr.args then
            error("Wrong number of arguments in funcall: "..pretty_print(expr))
        end

        local typed_args = {}
        for _, e in ipairs(expr.args) do
            table.insert(typed_args, typecheck(e))
        end

        local fn_impl
        for typ, impl in pairs(fn.impls) do
            local success = true
            for i, arg in ipairs(typed_args) do
                if arg.valtype ~= impl.sig[i] then
                    success = false
                    break
                end
            end
            if success then
                fn_impl = impl
                break
            end
        end
        if not fn_impl then
            error("Suitable function not found for expr: "..pretty_print(expr))
        end

        return {
            type = "funcall",
            valtype = fn_impl.valtype,
            impl = fn_impl.impl,
            args = typed_args
        }
    elseif expr.type == "operator" then
        if expr.first and expr.second then
            -- binary
            local args
            if expr.id == "=" then
                args = { { type="string", valtype="string", value=expr.first.value },
                         expr.second }
            else
                args = {expr.first, expr.second}
            end
            return typecheck({
                id = "funcall",
                name = {
                    type = "ident",
                    value = expr.id
                },
                args = args
            })
            --expr.valtype = unify_types_2(expr.id, expr.first, expr.second)
            --return expr.valtype
        elseif expr.first then
            -- unary
            local id
            if expr.id == "-" then
                id = "minus"
            else
                id = expr.id
            end
            return typecheck({
                id = "funcall",
                name = {
                    type = "ident",
                    value = id
                },
                args = {expr.first}
            })
        end
    end

    error("Typecheck failed on expr: "..pretty_print(expr))
end

function unify_types_2(op, a, b)
end

function wrap(val, typ)
    if typ == "int" then
        return `Cae.make_int(val)
    elseif typ == "float" then
        return `Cae.make_float(val)
    else
        return val
    end
end

function assign(expr)
    assert(expr.first.type == "ident")
    return quote
        var name = expr.first.value
        var val = [gencode(expr.second)]
        Cae.set_var(name, [wrap(val, "int")])
    in
        val
    end
end

function gencode(expr)
    if expr.type == "int" then
        return `[int](expr.value)
    end

    if expr.type == "float" then
        return `[float](expr.value)
    end

    if expr.type == "string" then
        return quote
            var len = Cstr.strlen(expr.value)
            var str: &int8 = [&int8](Cstd.malloc(len + 1))
            Cstr.memcpy(str, expr.value, len)
            str[len] = 0
        in
            str
        end
    end

    if expr.type == "ident_var" then
        local fn = extract_var[expr.valtype]
        return `[fn](expr.value)
    end

    if expr.type == "operator" then
        if expr.id == "=" then
            return assign(expr)
        elseif expr.second then
            local op = lookup_binop(expr.id)
            return op(gencode(expr.first), gencode(expr.second))
        else
            local op = lookup_unop(expr.id)
            return op(gencode(expr.first))
        end
    end

    if expr.type == "var" then
        if expr.second then
            return assign(expr)
        end
        return nil
    end

    --if expr.type == "ident" then
        ----print(expr.type)
        ----print(expr.value)
        --local typ = (terra()
            --var val: &Cae.value_t = Cae.get_var(expr.value)
            --if val == nil then
                --return 0
            --elseif Cae.is_int(val) then
                --return 1
            --elseif Cae.is_float(val) then
                --return 2
            --end
        --end)()
        ----print(typ)
        --if typ == 1 then
            --return quote
                --var val: &Cae.value_t = Cae.get_var(expr.value)
                --var result: int
                --if val ~= nil then
                    --result = Cae.take_int(val)
                --else
                    --result = 0
                --end
            --in
                --result
            --end
        --elseif typ == 2 then
            --return quote
                --var val: &Cae.value_t = Cae.get_var(expr.value)
                --var result: float
                --if val ~= nil then
                    --result = Cae.take_float(val)
                --else
                    --result = 0
                --end
            --in
                --result
            --end
        --end
    --end

    if expr.type == "funcall" then
        local args = terralib.newlist(expr.args)
        args = args:map(function(e)
            return gencode(e)
        end)
        return `expr.impl(args)
        --assert(expr.name.type == "ident")
        ---- Bulitin functions go first
        --if expr.name.value == "pras" then
            --local code = terra()
                --return [gencode(expr.args[1])]
            --end
            --code:disas()
            --return 0
        --end
        --if expr.name.value == "prpr" then
            --local code = terra()
                --return [gencode(expr.args[1])]
            --end
            --code:printpretty()
            --return 0
        --end
        --if expr.name.value == "prall" then
            --local code = terra()
                --return [gencode(expr.args[1])]
            --end
            --code:printpretty()
            --code:disas()
            --return 0
        --end

        --if Cmath[expr.name.value] then
            --local args = terralib.newlist(expr.args)
            --args = args:map(function(e)
                --return gencode(e)
            --end)
            --return `Cmath.[expr.name.value](args)
        --end
    end
end

function ae_eval(expr)
    local fun = gencode(expr)

    if expr.type == "int" then
        return fun()
    end

    if expr.type == "operator" then
        return fun(ae_eval(expr.first), ae_eval(expr.second))
    end
end

function make_literal(lit)
    return terra()
        return lit
    end
end

function make_binary_int(op)
    return terra(a: int, b: int)
        return op(a, b)
    end
end

function lookup_binop(op)
    if op == "+" then
        return function(a, b)
            return `a + b
        end
    end
    if op == "-" then
        return function(a, b)
            return `a - b
        end
    end
    if op == "*" then
        return function(a, b)
            return `a * b
        end
    end
    if op == "/" then
        return function(a, b)
            return `a / b
        end
    end
    if op == "**" then
        return function(a, b)
            return `Cmath.pow(a, b)
        end
    end
    if op == "==" then
        return function(a, b)
            return `a == b
        end
    end
    if op == "≠" then
        return function(a, b)
            return `a ~= b
        end
    end
    if op == "≤" then
        return function(a, b)
            return `a <= b
        end
    end
    if op == "<" then
        return function(a, b)
            return `a < b
        end
    end
    if op == "≥" then
        return function(a, b)
            return `a >= b
        end
    end
    if op == ">" then
        return function(a, b)
            return `a > b
        end
    end
end

function lookup_unop(op)
    if op == "-" then
        return function(a)
            return `-a
        end
    end
end

-- Stores all variables declared in the top-level scope
ae_vars = {}
