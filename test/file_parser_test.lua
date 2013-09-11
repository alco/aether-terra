require("lunit")

local Tokenizer = require("tokenizer")
local Parser = require("stat_parser")
local parser = Parser.new()

function all_stats(filename)
    local tt = Tokenizer.new{ file = filename }
    parser.tokenizer = tt
    local list = {}
    for _, s in ipairs(parser:all_statements()) do
        table.insert(list, s:format())
    end
    return list
end

assertEqList({
    "(block (var a 1) (var b (* a 2)) (- b a))",
    "(funcall some_func (a b c 1 2))",
    "(funcall other_func ((+ a b) (* 2 b) \"c\"))",
    "(= a (if this_is_true (funcall true (value)) (funcall false ())))",
    "(if (≤ a b) (* 4 5) (- 4))",
    "(var f (fn (x y z) (+ (+ x y) z)))",
    "(= f (fn () (+ (+ x y) z)))",
    "(= f (fn (sym#1 sym#2 sym#3) (+ (+ sym#1 sym#2) sym#3)))",
    "(= f (fn (sym#4 sym#5 sym#6) (+ (+ sym#4 (* sym#5 sym#5)) sym#6)))",
    "(= f (fn (sym#7 sym#8) (+ (+ sym#7 (* sym#8 sym#8)) 3)))",
    "(= f (+ (fn (sym#9 sym#10) (+ sym#9 (* sym#10 sym#10))) 3))",
    "(= f (fn (sym#11) sym#11))",
    "(= f (fn () 1))",
    "(+ (fn (sym#12 sym#13) (+ sym#12 (* sym#13 sym#13))) 3)",
    "(= f (+ (fn (sym#14 sym#15) (+ sym#14 (* sym#15 sym#15))) 3))",
}, all_stats("block_fixtures.ae"))

assertEqList({
    "(def pow(base exp))",
    "(def sqrt(x))",
    "(def cbrt(x))",
    "(def hypot(x y) (block))",
    "(def hypot(x y) (funcall sqrt ((+ (** x 2) (** y 2)))))",
    "(def sqr(x) (* x x))",
    "(def sqr(x) (** x 2))",
    "(def cub(x) (+ (** x 3) 1))",
}, all_stats("funcs.ae"))

