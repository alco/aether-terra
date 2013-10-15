-----------------------------------------------------------
-- ** Aether Compiler With Type Checking and Code Gen ** --
-----------------------------------------------------------


local Compiler = require("compiler")
local Util     = require("util")

--

local function table_size(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function table_concat(t1, t2)
    local len1 = #t1
    for i = 1,#t2 do
        t1[len1 + i] = t2[i]
    end
end

--

local function set_param(params, param, value)
    if params[param] and params[param] ~= value then
        return false
    end
    params[param] = value
    return true
end

local function match_type(tpat, typ, params)
    --print("Matching ")
    --Util.table_print(typ)
    --print(" against ")
    --Util.table_print(tpat)

    params = params or {}
    for k, v in pairs(tpat) do
        if type(v) == "table" then
            if v.param then
                if not set_param(params, v.param, typ[k]) then
                    Util.error("Failed to match "..typ:format().." against "..tpat:format())
                end
            else
                if not match_type(v, typ[k], params) then
                    return false
                end
            end
        elseif k ~= "format" and k ~= "codegen" then
            if v ~= typ[k] then
                return false
            end
        end
    end
    return params
end

local function reify_type_into(typ, params, newtype)
    for k, v in pairs(typ) do
        if type(v) == "table" then
            if v.param then
                if not params[v.param] then
                    Util.error("Could not resolve type parameter "..v.param)
                end
                newtype[k] = params[v.param]
            else
                local subtype = {}
                reify_type_into(v, params, subtype)
                newtype[k] = subtype
            end
        else
            newtype[k] = v
        end
    end
end

local function reify_type(typ, params)
    local newtype = {}
    reify_type_into(typ, params, newtype)
    return newtype
end


local function type_is_convertible(ty1, ty2)
    --print("***Calling match_type in is_convertible***")
    if match_type(ty1, ty2) then
        return true
    end
    ty1 = ty1:format()
    ty2 = ty2:format()
    return (ty1 == "int" and ty2 == "float")
        or (ty1 == "float" and ty2 == "int")
end

local function valid_type_for_vector(typ)
    typ = typ:format()
    return typ == "int" or typ == "float"
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

local function make_vector(len, elemtype)
    return {
        structure = "vector",
        len = len,
        elemtype = elemtype,
        format = function(self)
            local len = self.len
            if type(len) == "table" then
                len = len.param
            end
            return Util.strformat("({1}){2}", len, self.elemtype:format())
        end
    }
end

local function parse_type(typ)
    typ = typ:format()
    if typ == "int" or typ == "float" or typ == "bool" then
        return make_prim(typ)
    elseif string.match(typ, "%((%w)%)(%w+)") then
        local len, elemtype = string.match(typ, "%((%w)%)(%w+)")
        if tonumber(len) then
            return make_vector(tonumber(len), parse_type(elemtype))
        else
            return make_vector({ param = len }, parse_type(elemtype))
        end
    end
    Util.error("Cannot parse type "..typ)
end

local function parse_astype(typ)
    --print("Parsing astype")
    --print(typ:format())
    --Util.table_print(typ)
    if typ.id == "array" then
        return parse_type(Util.strformat("({1}){2}", typ.size.value, parse_astype(typ.elemtype):format()))
    else
        return parse_type(typ:format())
    end
end

local function parse_terratype(typ)
    if type(typ) == "string" then
        typ = parse_type(typ)
    end

    if typ.structure == "primitive" then
        if typ.name == "int" then
            return int
        elseif typ.name == "float" then
            return float
        elseif typ.name == "bool" then
            return bool
        else
            Util.error("Unhandled primitive type "..typ:format())
        end
    elseif typ.structure == "vector" then
        return parse_terratype(typ.elemtype)[typ.len]
    end
    print(debug.traceback())
    Util.error("Unhandled type "..typ)
end

--

local function make_variable(name, env, typ)
    local variable = {
        name = name,
        codegen = function(self)
            return self.sym
        end
    }
    if typ then
        variable.sym = symbol(typ, name)
    else
        variable.sym = symbol(name)
    end
    env[name] = variable
    return variable
end

local function make_conversion(val, typ)
    return {
        id = "as",
        valtype = typ,
        codegen = function(self)
            local terratyp = parse_terratype(typ)
            local v = val:codegen()
            return `[terratyp](v)
        end
    }
end

--

local function resolve_fn(name, args, env)
    -- FIXME: check in env first
    if name == "seq" then
        return {
            id = "stream",
            streamtype = "compile-time-sequence",
            seqstart = 0,
            seqstep = 1,
            seqend = args[1],
            valtype = {
                elemtype = make_prim("int")
            }
        }
    end
    Util.error("Unhandled function in resolve:"..name)
end

local function is_subscriptable(node)
    return node.valtype and node.valtype.structure == "vector"
end

--

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
        return parse_type(Util.strtrim(str))
    end)
    local ret = parse_type(comps[2])
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

local function make_unaryop_impl(id, types, retype, op)
    local clauses = {}
    for _, tstr in ipairs(types) do
        local typ = parse_terratype(tstr)
        local sig = Util.strformat("{1} -> {2}", tstr, retype or tstr)
        local opnode = parse_func(sig)
        opnode.id = id
        opnode.codegen = function(self)
            return quote
                var a: typ = [self.args[1]:codegen()]
            in
                op(a)
            end
        end
        table.insert(clauses, opnode)
    end
    return clauses
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

local function make_binop_impl(id, types, retype, op)
    local clauses = {}
    for _, tstr in ipairs(types) do
        local typ = parse_terratype(tstr)
        local sig = Util.strformat("{1} {1} -> {2}", tstr, retype or tstr)
        local opnode = parse_func(sig)
        opnode.id = id
        opnode.codegen = function(self)
            return quote
                var a: typ = [self.args[1]:codegen()]
                var b: typ = [self.args[2]:codegen()]
            in
                op(a, b)
            end
        end
        table.insert(clauses, opnode)
    end
    return clauses
end

function make_binop_vector_impl(id, types, op)
    local clauses = {}
    for _, tstr in ipairs(types) do
        local typ = parse_terratype(tstr)
        local sig = Util.strformat("(N){1} (N){1} -> (N){1}", tstr)
        local opnode = parse_func(sig)
        opnode.id = id
        opnode.codegen = function(params)
            local N = params["N"]
            return function(self)
                return quote
                    var a: typ[N] = [self.args[1]:codegen()]
                    var b: typ[N] = [self.args[2]:codegen()]
                    var result: typ[N]
                    for i = 0, N do
                        result[i] = op(a[i], b[i])
                    end
                in
                    result
                end
            end
        end
        table.insert(clauses, opnode)
    end
    return clauses
end

--

local function get_or_codegen(val)
    if type(val) == "table" then
        return val:codegen()
    elseif type(val) == "number" then
        return val
    end
    Util.error("Don't know how to handle the value: "..tostring(val))
end

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
            --print("***Looking for candidates ("..#candidates..") for "..name)
            for _, cand in ipairs(candidates) do
                --print("Candidate")
                --Util.table_print(cand)
                --print("===")
                if cand.nargs == #args then
                    local success = true

                    -- 1. Pattern match the arguments to resolve any parameters
                    -- 2. See if there are any parameters left over
                    -- 3. Check that all types are equal or there is an error

                    local params = {}
                    for i, carg in ipairs(cand.argtypes) do
                        local p = match_type(carg, args[i], params)
                        if not p then
                            --print("Failed match for "..carg:format().." and "..args[i]:format())
                            success = false
                            break
                        end
                        params = p
                    end
                    --for i, carg in ipairs(cand.argtypes) do
                    --    local typ = reify_type(carg, params)
                    --    if not match_type(typ, args[i]) then
                    --        success = false
                    --        break
                    --    end
                    --end

                    --params = resolve_type_params(cand.valtype, params)

                    if success then
                        if table_size(params) > 0 then
                            local valtype = reify_type(cand.valtype, params)
                            --print("Reified type = "..valtype:format())
                            cand = {
                                id = cand.id,
                                valtype = valtype,
                                codegen = cand.codegen(params)  -- Resolve parameters
                            }
                        end
                        table.insert(result, cand)
                    end
                end
            end
            if #result > 1 then
                --for _, r in ipairs(result) do
                --    Util.table_print(r)
                --    print("---")
                --end
                Util.error(tostring(#result).." conflicting overloads for "..name)
            end
            return result[1]
        end
    }

    checker.table = {
        ["int"] = make_numeric_lit("int"),
        ["float"] = make_numeric_lit("float"),
        ["true"] = function(checker, env, node)
            return {
                id = node.id,
                valtype = make_prim("bool"),
                codegen = function(self)
                    return `true
                end
            }
        end,
        ["false"] = function(checker, env, node)
            return {
                id = node.id,
                valtype = make_prim("bool"),
                codegen = function(self)
                    return `false
                end
            }
        end,
        ["vector"] = function(checker, env, node)
            if #node.args.exprs == 0 then
                Util.error("Empty vector does not make sense")
            end

            local args = Util.map(node.args.exprs, function(self)
                return checker:typecheck(self, env)
            end)
            local common_type = args[1].valtype
            if not valid_type_for_vector(common_type) then
                Util.error("Unsupported vector element type. Has to be a scalar")
            end
            for _, a in ipairs(args) do
                --print("***Calling match_type in vector***")
                if not match_type(common_type, a.valtype) then
                    Util.error("All vector elements have to be of the same type")
                end
            end

            return {
                id = node.id,
                valtype = make_vector(#args, common_type),
                codegen = function(self)
                    local terra_type = parse_terratype(common_type)
                    local targs = Util.map(args, function(self)
                        return self:codegen()
                    end)
                    return `arrayof(terra_type, targs)
                end
            }
        end,
        ["ident"] = function(checker, env, node)
            local variable = env[node.value]
            if not variable then
                Util.error("Undefined variable "..node.value)
            end
            if not variable.valtype then
                Util.error("Could not infer type for variable "..variable.name)
            end
            return variable
        end,
        ["as"] = function(checker, env, node)
            local val = checker:typecheck(node.first, env)
            local typ = parse_type(node.second)
            if not type_is_convertible(val.valtype, typ) then
                Util.error("No conversion from "..val.valtype:format().." to "..typ.name)
            end
            return make_conversion(val, typ)
        end,
        ["block"] = function(checker, env, node)
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
                        return quote mapped end
                    else
                        local expr = mapped[#mapped]
                        mapped:remove(#mapped)
                        return quote mapped in [expr] end
                    end
                end
            }
        end,
        ["funcall"] = function(checker, env, node)
            --Util.table_print(node)
            local targs = Util.map(node.args.exprs, function(expr)
                return checker:typecheck(expr, env)
            end)
            if node.name.id == "ident" then
                return resolve_fn(node.name.value, targs, env)
            end
            Util.error("Incomplete implementation of 'funcall' typechecking")
        end,
        ["for"] = function(checker, env, node)
            if node.head.id ~= "in" then
                Util.error("Expected 'for in'")
            end

            local coll = checker:typecheck(node.head.second, env)

            if node.body.id ~= "block" then
                Util.error("Expected a block as the loop body")
            end
            local variable = node.head.first
            if variable.id ~= "var" then
                Util.error("Expected a var statement before 'in'")
            end
            local tvar = checker:typecheck(variable, env) -- FIXME: do not polute current env
            if not tvar.vars[1].valtype then
                tvar.vars[1].valtype = coll.valtype.elemtype
            end

            local tblock = checker:typecheck(node.body, env)

            local retnode = {
                id = node.id,
                valtype = "void",
            }
            local loopvartype = parse_terratype(tvar.vars[1].valtype)
            if is_subscriptable(coll) then
                retnode.codegen = function(self)
                    return quote
                        for i = 0, [coll.valtype.len], 1 do
                            var [tvar.vars[1].sym]: loopvartype = [coll:codegen()][i]
                            [ tblock:codegen() ]
                        end
                    end
                end
            elseif coll.id == "stream" then
                if coll.streamtype == "compile-time-sequence" then
                    retnode.codegen = function(self)
                        local seqstart = get_or_codegen(coll.seqstart)
                        local seqstep = get_or_codegen(coll.seqstep)
                        local seqend = get_or_codegen(coll.seqend)
                        local s = tvar.vars[1].sym
                        return quote
                            var [s]: loopvartype
                            for [s] = [seqstart], [seqend], [seqstep] do
                                [ tblock:codegen() ]
                            end
                        end
                    end
                else
                    Util.error("Unhandled stream type: "..coll.streamtype)
                end
            else
                Util.error("Expected a subscriptable collection or a stream after 'in'")
            end
            return retnode
        end,
        ["fn"] = function(checker, env, node)
            --print(node.typ:format())
            --Util.table_print(node.typ)
            --Util.error("NOT IMPLEMENTED")

            if node.typ.id ~= "funcall" then
                Util.error("Wrong type for a function. Expected '... -> ...'")
            end

            local argtype = node.typ.first
            local rettype = node.typ.second

            if #node.args.exprs > 1 and argtype.id ~= "tuple" then
                Util.error("Mismatching type signature to the actual argument count")
            end

            -- Set up the arguments as local variables
            local arguments = terralib.newlist()
            for i, ident in ipairs(node.args.exprs) do
                local typ
                if argtype.id == "tuple" then
                    typ = argtype.args.exprs[i]
                else
                    typ = argtype
                end
                local valtype = parse_astype(typ)
                local terratyp = parse_terratype(valtype)
                local variable = make_variable(ident.value, env, terratyp)
                variable.valtype = valtype
                arguments:insert(variable.sym)
            end

            local fn_type = parse_astype(rettype)
            local fn_terratype = parse_terratype(fn_type)

            local tbody = checker:typecheck(node.body, env)
            if not match_type(tbody.valtype, fn_type) then
                Util.error("Mismatching types in function sig and last expr")
            end

            return {
                id = node.id,
                codegen = function(self)
                    local fn
                    if tbody.valtype == "void" then
                        fn = terra([arguments])
                            [ tbody:codegen() ]
                        end
                    else
                        fn = terra([arguments]): fn_terratype
                            return [ tbody:codegen() ]
                        end
                    end
                    return fn
                end
            }
        end,
        ["var"] = function(checker, env, node)
            -- FIXME check that env does not already contain declared vars
            local varnode = {
                id = node.id,
                valtype = "void",
                vars = {}
            }
            for _, v in ipairs(node.varlist.vars) do
                local variable = make_variable(v.name.value, env)
                if v.typ then
                    variable.valtype = parse_type(v.typ)
                end
                if v.value then
                    local val = checker:typecheck(v.value, env)
                    if variable.valtype then
                        if not type_is_convertible(variable.valtype, val.valtype) then
                            Util.error("Conflicting types in initialization")
                        end
                        variable.value = make_conversion(val, variable.valtype)
                    else
                        variable.valtype = val.valtype
                        variable.value = val
                    end
                end
                table.insert(varnode.vars, variable)
            end
            varnode.codegen = function(self)
                local vars = terralib.newlist()
                for _, v in ipairs(node.varlist.vars) do
                    local variable = env[v.name.value]
                    if not variable.valtype then
                        Util.error("Unknown type for variable "..v.name.value)
                    end
                    local typ = parse_terratype(variable.valtype:format())
                    local sym = variable.sym
                    if variable.value then
                        vars:insert(quote
                            var [sym] : typ = [ variable.value:codegen() ]
                        end)
                    else
                        vars:insert(quote var [sym] : typ end)
                    end
                end
                return `[vars]
            end
            return varnode
        end,
        ["="] = function(checker, env, node)
            local variable = env[node.name.value]
            if not variable then
                Util.error("Undefined variable in assignment: "..node.name.value)
            end

            local val = checker:typecheck(node.value, env)

            if val.valtype and variable.valtype and not type_is_convertible(val.valtype, variable.valtype) then
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
                    local val = make_conversion(val, variable.valtype)
                    local sym = variable.sym
                    return quote [sym] = [val:codegen()] end
                end
            }
        end
    }
    for _, unop in ipairs({"neg"}) do
        checker.table[unop] = make_unaryop()
    end
    for _, binop in ipairs({ "-", "+", "*", "/", "mod", "•", "==", ">", "≥", "<", "≤", "≠", "and", "or", "band", "bor", "<<" }) do
        checker.table[binop] = make_binop()
    end

    return checker
end

function new(opts)
    local doti = parse_func("(N)int (N)int -> int")
    doti.id = "dot"
    doti.codegen = function(params)
        local N = params["N"]
        return function(self)
            return quote
                var result: int = 0
                var a: int[N] = [self.args[1]:codegen()]
                var b: int[N] = [self.args[2]:codegen()]
                for i = 0, N do
                    result = result + a[i] * b[i]
                end
            in
                result
            end
        end
    end

    local dotf = parse_func("(N)float (N)float -> float")
    dotf.id = "dot"
    dotf.codegen = function(params)
        local N = params["N"]
        return function(self)
            return quote
                var result: float = 0
                var a: float[N] = [self.args[1]:codegen()]
                var b: float[N] = [self.args[2]:codegen()]
                for i = 0, N do
                    result = result + a[i] * b[i]
                end
            in
                result
            end
        end
    end

    local arith_types = {"int", "float"}

    local add_fn = macro(function(a, b) return `a + b end)
    local adds = make_binop_impl("+", arith_types, nil, add_fn)
    table_concat(adds, make_binop_vector_impl("+", arith_types, add_fn))

    local sub_fn = macro(function(a, b) return `a - b end)
    local subs = make_binop_impl("-", arith_types, nil, sub_fn)
    table_concat(subs, make_binop_vector_impl("-", arith_types, sub_fn))

    local mul_fn = macro(function(a, b) return `a * b end)
    local muls = make_binop_impl("*", arith_types, nil, mul_fn)
    table_concat(muls, make_binop_vector_impl("*", arith_types, mul_fn))

    local div_fn = macro(function(a, b) return `a / b end)
    local divs = make_binop_impl("/", arith_types, nil, div_fn)
    table_concat(divs, make_binop_vector_impl("/", arith_types, div_fn))

    local mod_fn = macro(function(a, b) return `a % b end)
    local mods = make_binop_impl("mod", {"int"}, nil, mod_fn)
    table_concat(mods, make_binop_vector_impl("mod", {"int"}, mod_fn))

    local builtin_env = {
        ["neg"] = make_unaryop_impl("neg", arith_types, nil, macro(function(a) return `-a end)),
        ["+"] = adds,
        ["-"] = subs,
        ["*"] = muls,
        ["/"] = divs,
        ["mod"] = mods,
        ["•"] = { doti, dotf },
        ["=="] = make_binop_impl("==", arith_types, "bool", macro(function(a, b) return `a == b end)),
        [">"] = make_binop_impl(">", arith_types, "bool", macro(function(a, b) return `a > b end)),
        ["≥"] = make_binop_impl("≥", arith_types, "bool", macro(function(a, b) return `a >= b end)),
        ["<"] = make_binop_impl("<", arith_types, "bool", macro(function(a, b) return `a < b end)),
        ["≤"] = make_binop_impl("≤", arith_types, "bool", macro(function(a, b) return `a <= b end)),
        ["≠"] = make_binop_impl("≠", arith_types, "bool", macro(function(a, b) return `a ~= b end)),
        ["and"] = make_binop_impl("and", {"bool"}, "bool", macro(function(a, b) return `a and b end)),
        ["or"] = make_binop_impl("or", {"bool"}, "bool", macro(function(a, b) return `a or b end)),
        ["band"] = make_binop_impl("band", {"int"}, "int", macro(function(a, b) return `a and b end)),
        ["bor"] = make_binop_impl("bor", {"int"}, "int", macro(function(a, b) return `a or b end)),
        ["<<"] = make_binop_impl("<<", {"int"}, "int", macro(function(a, b) return `a << b end)),
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
    compiler.codegen_single_function = function(expr)
        return expr:codegen()
    end
    return compiler
end

return {
    new = new
}
