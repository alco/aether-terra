require("lunit")

local parser = require("new_parser")
local Tokenizer = require("tokenizer")

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
    "(= f (fn () (+ (+ ➀ ➁) ➂)))"  -- FIXME: extract anonymous args
}, all_stats("block_fixtures.ae"))
