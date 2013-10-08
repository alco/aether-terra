require("lunit")

local Compiler = terralib.require("compiler")

function evalexpr(line)
    local compiler = Compiler.new { line = line }
    local expr = compiler.parse_single_expression()
    local typed_expr = compiler.typecheck_single_expression(expr)
    local terra_fn = compiler.codegen_single_expression(typed_expr)
    terra_fn:disas()
    return terra_fn()
end

---

assertEq(1, evalexpr("1"))
--assertEq(-1, evalexpr("-1"))
