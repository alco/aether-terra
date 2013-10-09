require("lunit")

local Compiler = terralib.require("compiler")

function evalexpr(line)
    local compiler = Compiler.new { line = line }
    local expr = compiler.parse_single_expression()
    local typed_expr = compiler.typecheck_single_expression(expr)
    local terra_fn = compiler.codegen_single_expression(typed_expr)
    --terra_fn:printpretty()
    return terra_fn()
end

---

assertEq(1, evalexpr("1"))
assertEq(-1, evalexpr("-1"))
assertEq(3, evalexpr("1+2"))
assertEq(-1, evalexpr("1-2"))
assertEq(15, evalexpr("3*5"))
assertEq(6, evalexpr("31/5"))

assertEq(0, evalexpr("0"))
assertEq(0, evalexpr("-0"))
assertEq(0, evalexpr("0-0"))
assertEq(0, evalexpr("0+0"))
assertEq(0, evalexpr("-0+1-0-1+0+0"))

assertEq(-18, evalexpr("(1 + (2 - 10) * 7) / 3"))

assertEq(0, evalexpr("0."))
assertEq(0.1, evalexpr("0.1"))
assertEq(1, evalexpr("1.0"))

assertEq(-1, evalexpr("-1.0"))
assertEq(-1, evalexpr("1.0 - 2.0"))
assertEq(2, evalexpr("1.0 + 1.0"))
assertEq(2.75, evalexpr("1.5 + 1.25"))
assertEq(0.25, evalexpr("1.5 - 1.25"))
assertEq(1.875, evalexpr("1.5 * 1.25"))
assertEq(3, evalexpr("1.5 / 0.5"))

--assertEq(0, evalexpr("a = 1; a / 2"))
