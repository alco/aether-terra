--
-- Read-eval-print loop for Aether
--

-- The parser does not keep any state from one expression to another,
-- so it is safe to reuse it.
local parser = require("new_parser")

local Tokenizer = require("tokenizer")

function aether_readline()
end

function doexpr(line)
    -- New tokenizer for each line.
    -- aether_readline() is a function exported from C
    local tt = Tokenizer.new({ line = line, readline_fn = aether_readline })
    parser.tokenizer = tt

    local expr = parser:expression()

    --local exprs = {}

    --while peekParseNode() and peekParseNode().id == ";" do
        --skip(";")
    --end

    --while peekParseNode() do
        --local result = expression()

        --if peekParseNode() and peekParseNode().id == ";" then
            --while peekParseNode() and peekParseNode().id == ";" do
                --skip(";")
            --end
        --else
            ---- Make sure there are no left-over tokens
            --expect(nil)
        --end

        --table.insert(exprs, result)
    --end

    ----print("Result node:")
    ----table_print(exprs)

    local exprs = {expr}
    local last_result = nil
    for _, expr in ipairs(exprs) do
        -- >>> pretty-print <<<
        print(expr:format())

        ---- >>> typecheck <<<
        --local typed_ast, action = typecheck(expr)
        --if not typed_ast then
            --error("Typecheck failed for expr: "..pretty_print(expr))
        --end

        ----if typed_ast.valtype then
            ----print("Typed root type = "..typed_ast.valtype)
        ----end

        ---- >>> evaluate <<<
        --local code = terra()
            --return [gencode(typed_ast)]
        --end

        --if action then
            ---- macro call
            --if action == "disas" then
                --code:disas()
            --elseif action == "pretty" then
                --code:printpretty()
            --elseif action == "all" then
                --code:printpretty()
                --code:disas()
            --end
            --break
        --end
        ----code:printpretty()
        ----code:disas()
        ----print("---")
        --local st_fn
        --if typed_ast.valtype == "int" then
            --st_fn = Cae.store_int
        --elseif typed_ast.valtype == "float" then
            --st_fn = Cae.store_float
        --elseif typed_ast.valtype == "string" then
            --st_fn = Cae.store_string
        --end
        --(terra() st_fn("_", code()) end)()
    end

    --(terra() Cae.print_result() end)()

    --return 1
end
