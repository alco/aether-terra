require("lunit")

local Util = require("util")
local Compiler = require("compiler")

function exprtype(line)
    local compiler = Compiler.new { line = line }
    return compiler.parse_single_expression():typecheck().valtype
end

--function expr_list(line)
    --local compiler = Compiler.new { line = line }
    --return compiler.parse_expr_list():format()
--end

--function stat(line)
    --local compiler = Compiler.new { line = line }
    --local stat = compiler.parse_single_statement()
    --if stat then
        --return stat:format()
    --end
--end

--function all_stats(line)
    --local compiler = Compiler.new { line = line }
    --local stats = compiler:parse()
    --return Util.map_format(stats)
--end

---

assertEq("int", exprtype("1"))
assertEq("int", exprtype("-1"))
assertEq("int", exprtype("1-1"))
assertEq("int", exprtype("1+1"))
