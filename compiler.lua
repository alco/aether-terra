---------------------------------------
-- ** Aether Compiler For Parsing ** --
---------------------------------------

-- Prevent modifications to global environment
local G = _G
local package_env = {}
setfenv(1, package_env)


Tokenizer = G.require("tokenizer")
Parser    = G.require("stat_parser")
Util      = G.require("util")

function new_parser(opts)
    local parser = Parser.new()
    parser.tokenizer = Tokenizer.new(opts)
    return parser
end

function new(opts)
    if opts.line and opts.file then
        G.error("Only one of 'line' or 'file' is allowed")
    elseif not (opts.file or opts.line) then
        G.error("One of 'line' or 'file' options is required")
    end

    local par = new_parser(opts)

    return {
        parse_single_expression = function()
            return new_parser(opts):expression()
        end,

        parse_expr_list = function()
            local parser = new_parser(opts)
            parser.tokenizer.skip("gparen")
            return parser:expr_list_until(")")
        end,

        parse_single_statement = function()
            return new_parser(opts):statement()
        end,

        parse = function(self)
            self.statements = par:all_statements()
            return self.statements
        end,

        --typecheck = function(self)
            --self.ast = typecheck(self.statements)
            --return self.ast
        --end,

        --specialize = function(self)
            --self.specialized_ast = specialize(self.ast)
            --return self.specialized_ast
        --end,

        --codegen = function(self)
            --self.code = codegen(self.specialized_ast)
            --return self.code
        --end
    }
end

return {
    new = new
}

--function expression(line)
--    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
--    parser.tokenizer = tt
--    return parser:expression():format()
--end
--
--function expr_list(line)
--    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
--    parser.tokenizer = tt
--    tt.skip("gparen")
--    return parser:expr_list_until(")"):format()
--end
--
--function stat(line)
--    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
--    parser.tokenizer = tt
--    local result = parser:statement()
--    if result then
--        return result:format()
--    end
--end
--
--function all_stats(line)
--    local tt = Tokenizer.new{ line = line, readline_fn = nilfn }
--    parser.tokenizer = tt
--    local list = {}
--    for _, s in ipairs(parser:all_statements()) do
--        table.insert(list, s:format())
--    end
--    return list
--end
--
--
--val_fn = function(self)
--    return self.value
--end
--id_fn = function(self)
--    return {
--        id = self.id,
--        value = self.tok.value,
--        format = val_fn,
--        visit = function(self, visitor)
--            visitor(self)
--        end
--    }
--end
--err_nud_fn = function(self)
--    Util.error("Trying to use '"..self.id.."' in prefix position.")
--end
--err_led_fn = function(self, left)
--    Util.error("Trying to use '"..self.id.."' in infix position after '"..left.id.."'.")
--end
--err_snud_fn = function(self)
--    Util.error("Trying to use '"..self.id.."' in statement position.")
--end
--err_sled_fn = function(self, left)
--    Util.error("Trying to use '"..self.id.."' in statement position after '"..left.id.."'.")
--end
--
--
--function new()
--    local node_table = {}
--    local parser = { node_table = node_table }
--
