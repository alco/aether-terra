require("lunit")

local Compiler = terralib.require("tcompiler")

function evalexpr(line, printcode)
    local compiler = Compiler.new { line = line }
    local expr = compiler.parse_single_expression()
    local typed_expr = compiler.typecheck_single_expression(expr)
    local terra_fn = compiler.codegen_single_expression(typed_expr)
    if printcode then
        print("*** Terra code:")
        terra_fn:printpretty()
        print()
        print("*** LLVM IR:")
        terra_fn:disas()
    end
    return terra_fn()
end

function evalfunc(line)
    local compiler = Compiler.new { line = line }
    local expr = compiler.parse_single_expression()
    local typed_expr = compiler.typecheck_single_expression(expr)
    local terra_fn = compiler.codegen_single_function(typed_expr)
    return terra_fn
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
assertEq(2, evalexpr("(var a int; var b = 2.5; a = b; a)"))  -- FIXME: add compiler option to forbid implicit truncation
assertEq(2, evalexpr("(var a int; var b = 2.5; a = b as int; a)"))

assertEq(2.5, evalexpr("(var a int; (var b = 2.5); b)")) -- FIXME: leaking scope

-- Vectors
assertError("No suitable overload for • with arg types int int in (• 1 2)", evalexpr, "1 • 2")

assertEq(9, evalexpr("(❮10❯ + ❮-1❯) • ❮1❯"))
assertEq(30, evalexpr("(❮10 8❯ + ❮-1, 13❯) • ❮1 1❯"))
assertEq(29, evalexpr("(❮10.0 8.0❯ + ❮-1.5, 12.5❯) • ❮1.0 1.0❯"))

assertEq(5, evalexpr("(❮10 8 4❯ - ❮-1, 13, 5❯) • ❮1 1 1❯"))
assertEq(1+4+9+16, evalexpr("(❮1 2 3 4❯ * ❮1 2 3 4❯) • ❮1 1 1 1❯"))
assertEq(0+1+1+2, evalexpr("(❮1 2 3 4❯ / ❮2 2 2 2❯) • ❮1 1 1 1❯"))
assertEq(0.5+1+1.5+2, evalexpr("(❮1.0 2.0 3.0 4.0❯ / ❮2.0 2.0 2.0 2.0❯) • ❮1.0 1.0 1.0 1.0❯"))

assertEq(-10, evalexpr("❮10❯ • ❮-1❯"))
assertEq(14, evalexpr("❮1 2❯ • ❮4 5❯"))
assertEq(32, evalexpr("❮1 2 3❯ • ❮4 5 6❯"))
assertEq(32, evalexpr("(var a = ❮1 2 3❯, b = ❮4 5 6❯; a • b)"))
assertEq(188.15625, evalexpr("❮0.125 0.5 0.25❯ • ❮100.5 200.75 300.875❯"))
assertEq(3.75, evalexpr("❮1.5❯ • ❮2.5❯"))

assertError("Failed to match (3)int against (N)float", evalexpr, "❮0.1 0.2❯ • ❮3 4 5❯")

-- FIXME: turn each test into a terra function

assertEq(true, evalexpr("0 == 0"))
assertEq(false, evalexpr("0 > 0"))
assertEq(true, evalexpr("0 ≥ 0"))
assertEq(false, evalexpr("0 < 0"))
assertEq(true, evalexpr("0 ≤ 0"))
assertEq(false, evalexpr("0 ≠ 0"))

assertEq(false, evalexpr("0 == 0 and 2 > 3"))
assertEq(false, evalexpr("0 > 0 or false"))
assertEq(true, evalexpr("0 > 0 or true"))
assertEq(false, evalexpr("true and false"))
assertEq(true, evalexpr("false and false or true"))
assertEq(false, evalexpr("false and (false or true)"))

assertEq(true, evalexpr("1.1 == 1.1"))
assertEq(true, evalexpr("1.21 > 1.20"))

-- NaN
assertEq(false, evalexpr("0.0/0.0 == 0.0/0.0"))
assertEq(false, evalexpr("0.0/0.0 > 0.0/0.0"))
assertEq(false, evalexpr("0.0/0.0 ≥ 0.0/0.0"))
assertEq(false, evalexpr("0.0/0.0 < 0.0/0.0"))
assertEq(false, evalexpr("0.0/0.0 ≤ 0.0/0.0"))
assertEq(false, evalexpr("0.0/0.0 ≠ 0.0/0.0"))

local sum = evalfunc([[
    fn(bytes) :: [9]int -> int (
        var sum = 0       // FIXME: add default initialization
        for var byte in bytes (
            sum = sum + byte
        )
        sum
    )
]])
--sum:printpretty()
--sum:disas()
local terra test_sum()
    var a = arrayof(int, 1, 2, 3, 4, 5, 6, 7, 8, 9)
    return sum(a)
end
assertEq(45, test_sum())


-- More complex blocks
assertEq(11403310, evalexpr([[
    (
        var MODULO = 65521
        var a = 1, b = 0
        var bytes = ❮1 2 3 4 5 6 7 8 9❯
        for var byte in bytes (
            a = (a + byte) mod MODULO
            b = (b + a) mod MODULO
        )
        (b << 16) bor a
    )
]], false))

local somefn = evalfunc([[
    fn(a b c) :: (int int int) -> int (
        a
    )
]])
assertEq(1, somefn(1,3,3))
assertEq(2, somefn(2,1,1))
assertEq(3, somefn(3,2,2))

local sum3 = evalfunc([[
    fn(a b c) :: (int int int) -> int (
        a + b + c
    )
]])
assertEq(6, sum3(1,2,3))

local adler32 = evalfunc([[
    fn(bytes) :: [9]int -> int (
        var MODULO = 65521
        var a = 1, b = 0
        for var byte in bytes (
            a = (a + byte) mod MODULO
            b = (b + a) mod MODULO
        )
        (b << 16) bor a
    )
]])
--adler32:printpretty()
--adler32:disas()
local terra test_adler32()
    var a = arrayof(int, 1, 2, 3, 4, 5, 6, 7, 8, 9)
    return adler32(a)
end
assertEq(11403310, test_adler32())

assertEq(45, evalexpr([[
    (
        var sum = 0
        for var i in seq(10) (
            sum = sum + i
        )
        sum
    )
]]))

local num_sum = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0   // FIXME: add default initialization
        for var i in seq(N) (
            sum = sum + i + 1
        )
        sum
    )
]])
--num_sum:printpretty()
--num_sum:disas()
local sum_acc = 0
for i = 0, 100 do
    sum_acc = sum_acc + i
    assertEq(sum_acc, num_sum(i))
end

local num_sum2 = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0   // FIXME: add default initialization
        for var i in seqi(N) (
            sum = sum + i
        )
        sum
    )
]])
--num_sum2:printpretty()
--num_sum2:disas()
sum_acc = 0
for i = 1, 100 do
    sum_acc = sum_acc + i
    assertEq(sum_acc, num_sum2(i))
end

local nth_fib = evalfunc([[
    fn(N) :: int -> int (
        var a = 0, b = 1
        for var i in seq(N) (
            // FIXME: ugly code
            var t = b
            b = a + b
            a = t
        )
        a
    )
]])
assertEq(0, nth_fib(0))
assertEq(1, nth_fib(1))
assertEq(1, nth_fib(2))
assertEq(21, nth_fib(8))
assertEq(144, nth_fib(12))

local seq1 = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0
        for var i in seq(2..N) (
            sum = sum + i
        )
        sum
    )
]])
assertEq(0, seq1(0))
assertEq(0, seq1(1))
assertEq(0, seq1(2))
assertEq(2, seq1(3))
assertEq(5, seq1(4))

local seq3 = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0
        for var i in seq(-2,1..N) (
            sum = sum + i
        )
        sum
    )
]])
assertEq(-2, seq3(0))
assertEq(-2, seq3(1))
assertEq(-1, seq3(2))
assertEq(-1, seq3(3))
assertEq(-1, seq3(4))
assertEq(3, seq3(5))

local seqm3 = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0
        for var i in seq(-2,-5..-N) (
            sum = sum + i
        )
        sum
    )
]])
assertEq(0, seqm3(0))
assertEq(0, seqm3(1))
assertEq(0, seqm3(2))
assertEq(-2, seqm3(3))
assertEq(-7, seqm3(6))

local seqm1 = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0
        for var i in seqi(200,199..N) (
            sum = sum + i
        )
        sum
    )
]])
assertEq(0, seqm1(201))
assertEq(200, seqm1(200))
assertEq(399, seqm1(199))

local seqi = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0
        for var i in seqi(1..N) (
            sum = sum + i
        )
        sum
    )
]])
assertEq(0, seqi(0))
assertEq(1, seqi(1))
assertEq(3, seqi(2))
assertEq(6, seqi(3))

--local modfilter = evalfunc([[
--fn(N) :: int -> int (
--    var sum = 0
--    for var i in seq(3..N) (
--        sum = sum + i
--    )
--    for var i in seq(5..N) (
--        if i mod 3 == 0 (
--            continue        // <--------
--        )
--        sum = sum + i
--    )
--    sum
--)
--]])

local breakfn = evalfunc([[
    fn(N) :: int -> int (
        var a = 1, b = 2
        var sum = 0
        for var i in seq(0..(N+100)) (
            if i == N (
                break  // <------------
            )
            sum = sum + a
            var t = a
            a = b
            b = a + t
        )
        sum
    )
]])
assertEq(0, breakfn(0))
assertEq(1, breakfn(1))
assertEq(3, breakfn(2))
assertEq(6, breakfn(3))
assertEq(11, breakfn(4))
assertEq(19, breakfn(5))

local ifexpr = evalfunc([[
    fn(N) :: int -> int (
        if (N > 0) 1 else 2
    )
]])
assertEq(1, ifexpr(1))
assertEq(1, ifexpr(10))
assertEq(2, ifexpr(0))
assertEq(2, ifexpr(-1))

local takefn = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0
        for var i in (seq(1,3..) -> take(N)) (
            sum = sum + i
        )
        sum
    )
]])
--takefn:printpretty()
--takefn:disas()
assertEq(1+3+5+7+9+11+13+15+17+19, takefn(10))

local takeminusfn = evalfunc([[
    fn(N) :: int -> int (
        var sum = 0
        for var i in (seq(1,-2..) -> take(N)) (
            sum = sum + i
        )
        sum
    )
]])
--takeminusfn:printpretty()
--takeminusfn:disas()
assertEq(1-2-5-8-11-14-17-20, takeminusfn(8))

--assertEq(45, evalexpr("seq(10) => '+"))
--assertEq(55, evalexpr("seqi(1..10) => '+"))
--
--assertEq(1+3+5+7+9, evalexpr("seq(1,3..11) => '+"))
--assertEq(1+3+5+7+9+11, evalexpr("seqi(1,3..11) => '+"))
--assertEq(1+3+5+7+9+11+13+15+17+19, evalexpr("seq(1,3..) -> take(10) => '+"))
--
--assertEq(45, evalexpr("fold('+, seq(10))"))
--assertEq(45, evalexpr("sum(seq(10))"))







--local fibs = evalfunc([[
--fn(N) :: int -> int (
--    var a = 1, b = 0
--    for b < N (
--        a, b = b, a+b
--    )
--    a
--)
--]])
