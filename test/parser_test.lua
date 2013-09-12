require("lunit")

local Tokenizer = require("tokenizer")
local Parser = require("stat_parser")
local parser = Parser.new()

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

assertEq("(+ (- 1) (- 2))", expr("-1 + -2"))
assertEq("(- (- 1) 2)", expr("-1 - 2"))
assertEq("(* (- 1) 2)", expr("-1 * 2"))
assertEq("(- (- 1))", expr("- -1"))
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

-- Arrays
assertEq("(array ())", expr("[]"))
assertEq("(array (1))", expr("[1]"))
assertEq("(array (1))", expr("[\n1\n]"))
assertEq("(array (1 2 \"str\" b))", expr("[1 2 \"str\" b]"))
assertEq("(array ((+ 1 2) \"str\" (- b)))", expr("[1+2, \"str\", -b]"))
assertError("Trying to use ':' in prefix position.", expr, "[1:2]")

-- Subscript
assertEq("(subscript a [])", expr("a[]"))
assertEq("(+ 1 (subscript a []))", expr("1+a[]"))
assertEq("(subscript a [1])", expr("a [1]"))   -- TODO: does it make sense to forbid whitespace?
assertEq("(subscript a [1])", expr("a[\n1\n]"))
assertEq("(subscript a (: 1 2))", expr("a[1:2]"))
assertEq("(subscript a (: 1 _))", expr("a[1:]"))
assertEq("(subscript a (: _ 2))", expr("a[:2]"))
assertEq("(subscript a (: _ _))", expr("a[:]"))
assertError("Unexpected token `term : ,`. Expected `]`", expr, "a[1,2]")

-- Ifs
assertEq("(if 1 2)", expr("if 1 2"))
assertEq("(if 1 2)", expr("if (1) 2"))
assertEq("(if 1 2)", expr("if 1 (2)"))
assertEq("(if 1 2)", expr("if (1) (2)"))
assertEq("(if 1 2 3)", expr("if (1) (2) else 3"))
assertEq("(if 1 2 3)", expr("if (1) (2) else (3)"))
assertEq("(if 1 2)", expr("if 1 (\n2)"))
assertEq("(if 1 2)", expr("if 1 (\n2\n)"))
assertError("1:1 Expected then-clause to begin on the same line", expr, "if (1)")
assertError("Unexpected end of input", expr, "if (1) 2 else")
assertError("1:1 Expected then-clause to begin on the same line", expr, "if (1)\n2")

-- Non-expressions
assertError("Trying to use 'var' in prefix position.",
            expr, "var a")
assertError("Trying to use 'var' in prefix position.",
            expr, "var a = 1")

-- Funcalls
assertEq("(funcall a ())", expr("a()"))
assertEq("(funcall a (1))", expr("a(1)"))
assertEq("(funcall a (1 2 3))", expr("a(1 2 3)"))
assertEq("(funcall a ((+ 1 2) (* 2 3) 4))", expr("a(1+2, 2*3, 4)"))

-- Expression list
assertEq("(a 1 b 2 \"c\" 3)", expr_list("(a 1 b 2 \"c\" 3)"))
assertEq("(a 1 b 2 \"c\" 3)", expr_list("(\na\n \n1 \nb \n2 \n\"c\" \n3\n)"))
assertError("Expected a literal or identifier. Got '(1)'", expr_list, "(a (1) b 2 ((c)) 3)")
assertError("Expected a literal or identifier. Got '(c)'", expr_list, "(a ((c)) 3)")
assertError("Expected a literal or identifier. Got '(funcall a (1))'", expr_list, "(a(1) b 2((c)) 3)")
assertError("Expected a literal or identifier. Got '(- a)'", expr_list, "(-a 1 -b 2* c -3)")

assertEq("(a 1 b 2 c 3)", expr_list("(a, (1), b, 2, ((c)), 3)"))
assertEq("((funcall a (1)) b (funcall 2 (c)) 3)", expr_list("(a(1), b, 2((c)), 3)"))
assertEq("((- a) 1 (- b) (* 2 c) (- 3))", expr_list("(-a, 1, -b, 2* c, -3)"))
assertError("Trying to use ',' in prefix position.", expr_list, "(a 1, b 2)")

-- Block (list of statements)
assertEq("(block)", expr("()"))
assertEq("(block ;)", expr("(;)"))
assertEq("(block)", expr("(\n)"))
assertEq("1", expr("(1)"))
assertEq("1", expr("(\n1\n)"))
assertEq("(block 1 2)", expr("(1;2)"))
assertEq("(block 1 2)", expr("(1\n2)"))
assertError("1:2 Expected newline or semicolon. Got '2'", expr, "(1 2)")
assertEq("(block 1)", expr("(1;)"))
assertEq("(block 1 ;)", expr("(1\n;)"))

-- Statements
assertEq(nil, stat(""))
assertEq(nil, stat("\n"))

assertEq("(var (a))", stat("var a"))
assertEq("(var (a (+ 1 2)))", stat("var a = 1 + 2"))
assertEq("(var (a 1) (b 2))", stat("var a = 1, b = 2"))
assertEq("(var (a:int))", stat("var a int"))
assertEq("(var (a:int) (b:int) (c:int))", stat("var a, b, c int"))

assertEq("(var (a:int))", stat("var a: int"))
assertEq("(var (a:uint (+ 1 2)))", stat("var a: uint = 1 + 2"))
assertEq("(var (a:int) (b:uint 5) (c:string))", stat("var a: int, b: uint = 5, c: string"))

assertEq("(block (var (a 1)) (* a 2) (block (+ 4 3) (- a)))",
         expr("(var a = 1; a * 2; (4 + 3; -a))"))
assertEq("(block (var (a 1)) (* a 2) (block (+ 4 3) (- a)))",
         expr("(\n\tvar a = 1\n\ta * 2\n\t(\n\t\t4 + 3\n\t\t-a\n\t)\n)"))

assertError("Unexpected 'int'. Expected 'ident'", stat, "var 1")
assertError("Unexpected 'gparen'. Expected 'ident'", stat, "var (a)")
--assertError("1:3 Expected newline or semicolon. Got '2'", stat, "var a 2")  FIXME: fix type_parser's error message
--assertError("1:3 Expected newline or semicolon. Got 'var'", stat, "var a var") FIXME: fix type_parser's error message
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

assertEqList({"(var (a))", "(= a (+ a 1))","(- 4)"}, all_stats("var a\na = a + 1\n-4;"))

-- Assignment
assertError("Unable to use '=' in expression", expr, "a = 1")
assertEq("(= a 1)", stat("a = 1"))

-- Function definition
assertEq("(def sin(x))", stat("def sin(x)"))
assertEq("(def pow(base exp))", stat("def pow(base exp)"))
assertEq("(def sin(x))", stat("def sin(x) :: flt -> flt"))
assertEq("(def pow(base exp))", stat("def pow(base exp) :: (flt flt) -> flt"))
assertError("Trying to use 'def' in prefix position.", expr, "def sin(x)")
assertError("Unexpected 'gparen'. Expected 'ident'", stat, "def (sin(x))")
assertError("Unexpected end of input", stat, "def x")
assertError("Unexpected 'int'. Expected 'cparen'", stat, "def x 1")
