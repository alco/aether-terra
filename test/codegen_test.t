require("lunit")

local Compiler = terralib.require("tcompiler")

function evalexpr(line)
    local compiler = Compiler.new { line = line }
    local expr = compiler.parse_single_expression()
    local typed_expr = compiler.typecheck_single_expression(expr)
    local terra_fn = compiler.codegen_single_expression(typed_expr)
    --terra_fn:printpretty()
    terra_fn:disas()
    --print("***********")
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

assertEq(2.5, evalexpr("(1 + 1; 2.5)"))
assertEq(3, evalexpr("(1 + 1; 2 * 2; 6 - 3)"))

assertEq(nil, evalexpr("(var a int)"))
assertEq(nil, evalexpr("(var a float; a = 2.5)"))
assertEq(2.5, evalexpr("(var a float; a = 2.5; a)"))
assertEq(1.5, evalexpr("(var a, b float; a = 2.5; b = -1.0; a + b)"))
assertEq(1.5, evalexpr("(var a = 2.5, b = -1.0 float; a + b)"))
assertEq(2.5, evalexpr("(var a:float = 2.5, b:int = -1; a)"))
assertEq(-1, evalexpr("(var a:float = 2.5, b:int = -1; b)"))

assertError("Could not infer type for variable a", evalexpr, "(var a; a)")

assertEq(nil, evalexpr("(var a; a = 2.5)"))
assertEq(2.5, evalexpr("(var a; a = 2.5; a)"))

assertEq(2.0, evalexpr("2 as float"))
assertEq(2, evalexpr("2.1 as int"))
assertEq(2.0, evalexpr("(var a:float = 2; a)"))

assertEq(2.5, evalexpr("(var a int; var b = 2.5; b)"))
assertEq(2, evalexpr("(var a int; var b = 2.5; a = b; a)"))

-- FIXME: turn each test into a terra function
