-----------------------------------------------------------
-- ** Aether Compiler With Type Checking and Code Gen ** --
-----------------------------------------------------------


local Compiler = require("compiler")
local Util     = require("util")

--

local function types_agree(ty1, ty2)
    return ty1:format() == ty2:format()
end

--

local function make_prim(name)
    return {
        structure = "primitive",
        name = name,
        format = function(self)
            return self.name
        end
    }
end

--

local function parse_terratype(typ)
    typ = typ:format()
    if typ == "int" then
        return int
    elseif typ == "float" then
        return float
    end
    Util.error("Unhandled type "..typ)
end

local function parse_type(typ)
    typ = typ:format()
    if typ == "int" or typ == "float" then
        return make_prim(typ)
    end
    Util.error("Cannot parse type "..typ)
end

local function make_func(ret, args)
    return {
        structure = "function",
        nargs = #args,
        argtypes = args,
        valtype = ret
    }
end

local function parse_func(spec)
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

local function make_numeric_lit(typ)
    return function(_checker, _env, node)
        return {
            id = node.id,
            value = node.value,
            valtype = make_prim(typ),
            codegen = function(self)
                local num = tonumber(self.value)
                return `num
            end
        }
    end
end

local function make_unaryop()
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

local function make_binop()
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

local function new_typechecker(env)
    local checker = {
        env = env,

        typecheck = function(self, expr, env)
            env = env or self.env
            local typecheck_fn = self.table[expr.id]
            if not typecheck_fn then
                Util.error("No typechecking for "..expr.id.." in "..expr:format())
            end
            return typecheck_fn(self, env, expr)
        end,

        findfunc = function(self, env, name, args)
            local candidates = env[name]
            if not candidates then
                return
            end

            local result = {}
            for _, cand in ipairs(candidates) do
                if cand.nargs == #args then
                    local success = true
                    for i, ty in ipairs(cand.argtypes) do
                        if not types_agree(args[i], ty) then
                            success = false
                            break
                        end
                    end
                    if success then
                        table.insert(result, cand)
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
        ident = function(checker, env, node)
            local variable = env[node.value]
            if not variable then
                Util.error("Undefined variable "..node.value)
            end
            if not variable.valtype then
                Util.error("Could not infer type for variable "..variable.name)
            end
            return variable
        end,
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
                    local mapped = stats:map(function(self)
                        return self:codegen()
                    end)
                    if self.valtype == "void" then
                        return mapped
                    else
                        local expr = mapped[#mapped]
                        mapped:remove(#mapped)
                        return quote
                            mapped
                        in
                            [expr]
                        end
                    end
                end
            }
        end,
        ["var"] = function(checker, env, node)
            -- FIXME check that env does not already contain declared vars
            for _, v in ipairs(node.varlist.vars) do
                local variable = {
                    name = v.name.value,
                    codegen = function(self)
                        return self.sym
                    end
                }
                if v.typ then
                    variable.valtype = parse_type(v.typ)
                    variable.sym = symbol(parse_terratype(v.typ), v.name.value)
                else
                    variable.sym = symbol(v.name.value)
                end
                if v.value then
                    local val = checker:typecheck(v.value, env)
                    if variable.valtype and not types_agree(variable.valtype, val.valtype) then
                        Util.error("Conflicting types in initialization")
                    end
                    variable.value = val
                end
                env[v.name.value] = variable
            end
            return {
                id = node.id,
                valtype = "void",
                codegen = function(self)
                    local vars = terralib.newlist()
                    for _, v in ipairs(node.varlist.vars) do
                        if not v.typ then
                            Util.error("Could not infer the type for variable "..v.name.value)
                        end
                        local variable = env[v.name.value]
                        local sym = variable.sym
                        if variable.value then
                            vars:insert(quote
                                var [sym] : parse_terratype(v.typ) = [ variable.value:codegen() ]
                            end)
                        else
                            vars:insert(quote var [sym] : parse_terratype(v.typ) end)
                        end
                    end
                    return `[vars]
                end
            }
        end,
        ["="] = function(checker, env, node)
            local variable = env[node.name.value]
            if not variable then
                Util.error("Undefined variable "..node.name.value)
            end

            local val = checker:typecheck(node.value, env)

            if val.valtype and variable.valtype and not types_agree(val.valtype, variable.valtype) then
                Util.error("Conflicting types in assignment: "..val.valtype:format().." and "..variable.valtype:format())
            elseif not variable.valtype then
                variable.valtype = val.valtype
            end
            if not val.valtype and not variable.valtype then
                Util.error("No type information in assignment")
            end

            return {
                id = node.id,
                valtype = "void",
                codegen = function(self)
                    local sym = variable.sym
                    return quote [sym] = [val:codegen()] end
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

    local compiler = Compiler.new(opts)
    compiler.typecheck_single_expression = function(expr)
        return new_typechecker(builtin_env):typecheck(expr)
    end
    compiler.codegen_single_expression = function(expr)
        local code = expr:codegen()
        if expr.valtype == "void" then
            code = quote code end
        else
            code = quote return code end
        end
        local terra fn()
            code
        end
        return fn
    end
    return compiler
end

return {
    new = new
}
