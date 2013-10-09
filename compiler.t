---------------------------
-- ** Aether Compiler ** --
---------------------------

-- Prevent modifications to global environment
local G = _G
local package_env = {}
--setfenv(1, package_env)


Tokenizer = G.require("tokenizer")
Parser    = G.require("stat_parser")
Util      = G.require("util")

function new_parser(opts)
    local parser = Parser.new()
    parser.tokenizer = Tokenizer.new(opts)
    return parser
end

function types_agree(ty1, ty2)
    return ty1:format() == ty2:format()
end

--

function make_prim(name)
    return {
        structure = "primitive",
        name = name,
        format = function(self)
            return self.name
        end
    }
end

function make_func(ret, args)
    return {
        structure = "function",
        nargs = #args,
        argtypes = args,
        valtype = ret
    }
end

function parse_func(spec)
    local comps = Util.map(Util.strsplit(spec, "->"), function(str)
        return Util.strtrim(str)
    end)
    local args = Util.map(Util.strsplit(comps[1]), function(str)
        return Util.strtrim(str)
    end)
    local ret = comps[2]
    return make_func(ret, args)
end

--

function make_numeric_lit(typ)
    return function(_checker, _env, node)
        return {
            id = node.id,
            value = node.value,
            valtype = make_prim(typ),
            codegen = function(self)
                local num = G.tonumber(self.value)
                return `num
            end
        }
    end
end

function make_unaryop()
    return function(checker, env, node)
        local arg = checker:typecheck(node.first, env)
        local fn = checker:findfunc(env, node.id, {arg.valtype})
        if not fn then
            Util.error("No suitable overload for "..node.id.." with arg type "..arg.valtype:format().." in "..node:format())
        end
        return {
            id = fn.id,
            args = { arg },
            valtype = fn.valtype,
            codegen = fn.codegen,
        }
    end
end
function make_binop()
    return function(checker, env, node)
        local args = Util.map({node.first, node.second}, function(node)
            return checker:typecheck(node, env)
        end)
        local types = Util.map(args, function(arg)
            return arg.valtype
        end)
        local fn = checker:findfunc(env, node.id, types)
        if not fn then
            local typstrings = Util.map(args, function(arg)
                return arg.valtype:format()
            end)
            Util.error("No suitable overload for "..node.id.." with arg types "..Util.strjoin(typstrings, " ").." in "..node:format())
        end
        return {
            id = fn.id,
            args = args,
            valtype = fn.valtype,
            codegen = fn.codegen
        }
    end
end

--

function new_typechecker(env)
    local checker = {
        env = env,

        typecheck = function(self, expr, env)
            env = env or self.env
            local typecheck_fn = self.table[expr.id]
            if not typecheck_fn then
                Util.error("No typechecking for "..expr:format())
            end
            return typecheck_fn(self, env, expr)
        end,

        findfunc = function(self, env, name, args)
            local candidates = env[name]
            if not candidates then
                return
            end

            local result = {}
            for _, cand in G.ipairs(candidates) do
                if cand.nargs == #args then
                    local success = true
                    for i, ty in G.ipairs(cand.argtypes) do
                        if not types_agree(args[i], ty) then
                            success = false
                            break
                        end
                    end
                    if success then
                        G.table.insert(result, cand)
                    end
                end
            end
            if #result > 1 then
                Util.error(tostring(#result).." conflicting overloads for "..name)
            end
            return result[1]
        end
    }

    checker.table = {
        int = make_numeric_lit("int"),
        float = make_numeric_lit("float"),
        block = function(checker, env, node)
            -- FIXME: create new scope
            local stats = terralib.newlist()
            local st
            for _, s in ipairs(node.stats) do
                st = checker:typecheck(s, env)
                stats:insert(st)
            end
            return {
                id = "block",
                valtype = st.valtype,
                codegen = function(self)
                    if self.valtype.name == "void" then
                        return stats:map(function(self)
                            return self:codegen()
                        end)
                    else
                        stats:remove(#stats)
                        return quote
                            [ stats:map(function(self)
                                return self:codegen()
                            end) ]
                        in
                            [ st:codegen() ]
                        end
                    end
                end
            }
        end,
        ["neg"] = make_unaryop(),
        ["-"] = make_binop(),
        ["+"] = make_binop(),
        ["*"] = make_binop(),
        ["/"] = make_binop(),
    }

    return checker
end

function new(opts)
    if opts.line and opts.file then
        G.error("Only one of 'line' or 'file' is allowed")
    elseif not (opts.file or opts.line) then
        G.error("One of 'line' or 'file' options is required")
    end

    local negi = parse_func("int -> int")
    negi.id = "neg"
    negi.codegen = function(self)
        local terra neg(arg: int)
            return -arg
        end
        return `neg([self.args[1]:codegen()])
    end

    local negf = parse_func("float -> float")
    negf.id = "neg"
    negf.codegen = function(self)
        local terra neg(arg: float)
            return -arg
        end
        return `neg([self.args[1]:codegen()])
    end

    local addi = parse_func("int int -> int")
    addi.id = "+"
    addi.codegen = function(self)
        local terra add(a: int, b: int)
            return a + b
        end
        return `add([self.args[1]:codegen()], [self.args[2]:codegen()])
    end

    local addf = parse_func("float float -> float")
    addf.id = "+"
    addf.codegen = function(self)
        local terra add(a: float, b: float)
            return a + b
        end
        return `add([self.args[1]:codegen()], [self.args[2]:codegen()])
    end

    local subi = parse_func("int int -> int")
    subi.id = "-"
    subi.codegen = function(self)
        local terra sub(a: int, b: int)
            return a - b
        end
        return `sub([self.args[1]:codegen()], [self.args[2]:codegen()])
    end

    local subf = parse_func("float float -> float")
    subf.id = "-"
    subf.codegen = function(self)
        local terra sub(a: float, b: float)
            return a - b
        end
        return `sub([self.args[1]:codegen()], [self.args[2]:codegen()])
    end

    local muli = parse_func("int int -> int")
    muli.id = "*"
    muli.codegen = function(self)
        local terra mul(a: int, b: int)
            return a * b
        end
        return `mul([self.args[1]:codegen()], [self.args[2]:codegen()])
    end

    local mulf = parse_func("float float -> float")
    mulf.id = "*"
    mulf.codegen = function(self)
        local terra mul(a: float, b: float)
            return a * b
        end
        return `mul([self.args[1]:codegen()], [self.args[2]:codegen()])
    end

    local divi = parse_func("int int -> int")
    divi.id = "/"
    divi.codegen = function(self)
        local terra div(a: int, b: int)
            return a / b
        end
        return `div([self.args[1]:codegen()], [self.args[2]:codegen()])
    end

    local divf = parse_func("float float -> float")
    divf.id = "/"
    divf.codegen = function(self)
        local terra div(a: float, b: float)
            return a / b
        end
        return `div([self.args[1]:codegen()], [self.args[2]:codegen()])
    end

    local builtin_env = {
        ["neg"] = { negi, negf },
        ["+"] = { addi, addf },
        ["-"] = { subi, subf },
        ["*"] = { muli, mulf },
        ["/"] = { divi, divf },
    }

    local par = new_parser(opts)

    return {
        parse_single_expression = function()
            return new_parser(opts):expression()
        end,

        typecheck_single_expression = function(expr)
            return new_typechecker(builtin_env):typecheck(expr)
        end,

        codegen_single_expression = function(expr)
            local terra fn()
                return [ expr:codegen() ]
            end
            return fn
        end,

        parse_expr_list = function()
            local parser = new_parser(opts)
            parser.tokenizer.skip("gparen")
            return parser:expr_list_until(")")
        end,

        parse_single_statement = function()
            return new_parser(opts):statement()
        end,

        parse = function(self)
            self.statements = par:all_statements()
            return self.statements
        end,

        typecheck = function(self)
            self.ast = typecheck(self.statements)
            return self.ast
        end,

        specialize = function(self)
            self.specialized_ast = specialize(self.ast)
            return self.specialized_ast
        end,

        codegen = function(self)
            self.code = codegen(self.specialized_ast)
            return self.code
        end
    }
end

return {
    new = new
}

--function expression(line)
--    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
--    parser.tokenizer = tt
--    return parser:expression():format()
--end
--
--function expr_list(line)
--    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
--    parser.tokenizer = tt
--    tt.skip("gparen")
--    return parser:expr_list_until(")"):format()
--end
--
--function stat(line)
--    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
--    parser.tokenizer = tt
--    local result = parser:statement()
--    if result then
--        return result:format()
--    end
--end
--
--function all_stats(line)
--    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
--    parser.tokenizer = tt
--    local list = {}
--    for _, s in ipairs(parser:all_statements()) do
--        table.insert(list, s:format())
--    end
--    return list
--end
--
--
--val_fn = function(self)
--    return self.value
--end
--id_fn = function(self)
--    return {
--        id = self.id,
--        value = self.tok.value,
--        format = val_fn,
--        visit = function(self, visitor)
--            visitor(self)
--        end
--    }
--end
--err_nud_fn = function(self)
--    Util.error("Trying to use '"..self.id.."' in prefix position.")
--end
--err_led_fn = function(self, left)
--    Util.error("Trying to use '"..self.id.."' in infix position after '"..left.id.."'.")
--end
--err_snud_fn = function(self)
--    Util.error("Trying to use '"..self.id.."' in statement position.")
--end
--err_sled_fn = function(self, left)
--    Util.error("Trying to use '"..self.id.."' in statement position after '"..left.id.."'.")
--end
--
--
--function new()
--    local node_table = {}
--    local parser = { node_table = node_table }
--
