require("lunit")

local parser = require("new_parser")
local Tokenizer = require("tokenizer")

function nilfn()
end

function expr(line)
    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
    parser.tokenizer = tt
    return parser:expression():format()
end

function expr_list(line)
    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
    parser.tokenizer = tt
    tt.skip("gparen")
    return parser:expr_list_until(")"):format()
end

function stat(line)
    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
    parser.tokenizer = tt
    return parser:statement():format()
end

---

-- Basic literal tests
assertEq("1", expr("1"))
assertEq("1.", expr("1."))
assertEq("1.3", expr("1.3"))
assertEq("a", expr("a"))
assertEq("abc'", expr("abc'"))
assertEq("x?", expr("x?"))
assertEq("hello\tworld", expr("\"hello\\tworld\""))

-- Arithmetic
assertEq("(+ 1 1)", expr("1+1"))
assertEq("(+ (+ 1 2) (* 3 4))", expr("1+2+3*4"))
assertEq("(- 1. 0)", expr("1.-0"))
assertEq("(- 1.3)", expr("-1.3"))
assertEq("(- a)", expr("-a"))
assertEq("(+ (* abc' 2) 4)", expr("abc'*2+4"))
assertEq("(+ 4 (* 2 x?))", expr("4+2*x?"))
assertEq("(/ (/ 1 2) 3)", expr("1/2/3"))
assertEq("(+ (** 2 (** 3 4)) 1)", expr("2**3**4+1"))
assertEq("(* (* 2 (** 3 4)) 5)", expr("2*3**4*5"))
assertEq("(• (* (/ 1 2) 3) 4)", expr("1/2*3•4"))
assertEq("(• (/ (- 1) (- (** 2 (- 3)))) (- 4))", expr("-1/-2**-3•-4"))

-- Comparisons
assertEq("(== a (< b c))", expr("a == b < c"))
assertEq("(≠ (> a b) c)", expr("a > b ≠ c"))
assertEq("(≥ (≤ a b) c)", expr("a ≤ b ≥ c"))
assertEq("(== (≠ a b) c)", expr("a ≠ b == c"))

-- Grouping
assertEq("1", expr("(1)"))
assertEq("1.", expr("((1.))"))
assertEq("1.3", expr("( \t\n1.3\n\t)"))
assertEq("a", expr("( \t(\n a\n)\n\n)"))
assertEq("(- (* (+ 1 2) (+ 3 4)) (* 5 (/ 7 (- 8 1))))",
         expr("(1 + 2) * (3 + 4) - 5*(7/(8-1))"))
assertEq("(- (** (/ 1 (- 2)) (- (• 3 (- 4)))))",
         expr("-(1/-2)**(-(3•-4))"))

-- Non-expressions
assertError("Trying to use 'var' in prefix position.",
            expr, "var a")
assertError("Trying to use 'var' in prefix position.",
            expr, "var a = 1")

-- Expression list
assertEq("(a 1 b 2 c 3)", expr_list("(a (1) b 2 ((c)) 3)"))
assertEq("((funcall a (1)) b (funcall 2 (c)) 3)", expr_list("(a(1) b 2((c)) 3)"))
assertEq("((- a) (- 1 b) (- (* 2 c) 3))", expr_list("(-a 1 -b 2* c -3)"))

assertEq("(a 1 b 2 c 3)", expr_list("(a, (1), b, 2, ((c)), 3)"))
assertEq("((funcall a (1)) b (funcall 2 (c)) 3)", expr_list("(a(1), b, 2((c)), 3)"))
assertEq("((- a) 1 (- b) (* 2 c) (- 3))", expr_list("(-a, 1, -b, 2* c, -3)"))
assertError("Trying to use ',' in prefix position.", expr_list, "(a 1, b 2)")

-- Block (list of statements)

-- Statements
assertEq("(var a)", stat("var a"))
assertEq("(var a (+ 1 2))", stat("var a = 1 + 2"))
assertError("Unexpected 'int'. Expected 'ident'", stat, "var 1")
assertError("Unexpected 'gparen'. Expected 'ident'", stat, "var (a)")
assertError("1:3 Expected newline or semicolon. Got '2'", stat, "var a 2")
assertError("1:3 Expected newline or semicolon. Got 'var'", stat, "var a var")
assertError("Trying to use 'var' in prefix position.", stat, "var a = var b")
