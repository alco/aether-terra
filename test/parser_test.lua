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
    local result = parser:statement()
    if result then
        return result:format()
    end
end

function all_stats(line)
    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
    parser.tokenizer = tt
    local list = {}
    for _, s in ipairs(parser:all_statements()) do
        table.insert(list, s:format())
    end
    return list
end

---

-- Basic literal tests
assertEq("1", expr("1"))
assertEq("1.", expr("1."))
assertEq("1.3", expr("1.3"))
assertEq("a", expr("a"))
assertEq("abc'", expr("abc'"))
assertEq("x?", expr("x?"))
assertEq("\"hello\tworld\"", expr("\"hello\\tworld\""))

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
assertEq("(a 1 b 2 \"c\" 3)", expr_list("(a 1 b 2 \"c\" 3)"))

-- FIXME: disallow complex expressions with no commas
assertError("(a 1 b 2 c 3)", expr_list, "(a (1) b 2 ((c)) 3)")
assertError("((funcall a (1)) b (funcall 2 (c)) 3)", expr_list, "(a(1) b 2((c)) 3)")
assertError("((- a) (- 1 b) (- (* 2 c) 3))", expr_list, "(-a 1 -b 2* c -3)")

assertEq("(a 1 b 2 c 3)", expr_list("(a, (1), b, 2, ((c)), 3)"))
assertEq("((funcall a (1)) b (funcall 2 (c)) 3)", expr_list("(a(1), b, 2((c)), 3)"))
assertEq("((- a) 1 (- b) (* 2 c) (- 3))", expr_list("(-a, 1, -b, 2* c, -3)"))
assertError("Trying to use ',' in prefix position.", expr_list, "(a 1, b 2)")

-- Block (list of statements)
--assertEq("(block (var a 1) (* a 2) (block (+ 4 3) (- a)))",
         --expr("(var a = 1; a * 2; (4 + 3; -a))"))
--assertEq("(block (var a 1) (* a 2) (block (+ 4 3) (- a)))",
         --expr("(\n\tvar a = 1\n\ta * 2\n\t(\n\t\t4 + 3\n\t\t-a\n\t)\n)"))

-- Statements
assertEq(nil, stat(""))
assertEq(nil, stat("\n"))
assertEq("(var a)", stat("var a"))
assertEq("(var a (+ 1 2))", stat("var a = 1 + 2"))
assertError("Unexpected 'int'. Expected 'ident'", stat, "var 1")
assertError("Unexpected 'gparen'. Expected 'ident'", stat, "var (a)")
assertError("1:3 Expected newline or semicolon. Got '2'", stat, "var a 2")
assertError("1:3 Expected newline or semicolon. Got 'var'", stat, "var a var")
assertError("Trying to use 'var' in prefix position.", stat, "var a = var b")

-- Newlines and semicolons
assertEq("1", expr("1\n"))
assertEq("1", expr("\n1"))
assertEq("1", expr("\t \n1"))

assertEq("(+ 1 2)", expr("\n1 + 2"))
assertEq("1", expr("1\n + 2"))
assertEq("(+ 1 2)", expr("1 +\n 2"))

assertEq("1", stat("1\n + 2"))
assertEq("(+ 1 2)", stat("1 +\n 2"))
--assertError("", all_stats, "1\n + 2")

assertEq(";", stat(";"))
assertEq(";", stat(";;"))
assertEq(";", stat(";1"))
assertEq(";", stat("\n;"))

assertEqList({";"}, all_stats(";"))
assertEqList({";",";"}, all_stats(";;"))
assertEqList({";","1"}, all_stats(";1"))
assertEqList({";","1"}, all_stats(";1;"))
assertEqList({";"}, all_stats("\n\n;"))
assertEqList({";","1",";",";"}, all_stats("\n;1;;\n;"))
assertEqList({"1",";"}, all_stats("1\n;"))
assertEqList({"1"}, all_stats("1;"))
assertEqList({}, all_stats("\n"))
assertEqList({"1"}, all_stats("1;\n"))
assertEqList({";","1",";"}, all_stats("\n;\n1;\n;\n"))
assertEqList({";","1",";"}, all_stats("\n;\n1\n;\n"))

assertEqList({"(var a)", "(= a (+ a 1))","(- 4)"}, all_stats("var a\na = a + 1\n-4;"))

-- Assignment
assertError("Unable to use '=' in expression", expr, "a = 1")
assertEq("(= a 1)", stat("a = 1"))
