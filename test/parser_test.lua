require("lunit")

local parser = require("new_parser")
local Tokenizer = require("tokenizer")

function aether_readline()
end

function expr(line)
    local tt = Tokenizer.new({ line = line, readline_fn = aether_readline })
    parser.tokenizer = tt
    return parser:expression():format()
    --local stats = parser:all_statements()
    --for i, s in ipairs(stats) do
        --stats[i] = s:format()
    --end
    --return stats
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
