---------------------------
-- ** Aether Compiler ** --
---------------------------

-- Prevent modifications to global environment
local G = _G
local package_env = {}
setfenv(1, package_env)


Tokenizer = G.require("tokenizer")
Parser    = G.require("stat_parser")


function new(opts)
    local compiler = {}

    if opts.line and opts.file then
        G.error("Only one of 'line' or 'file' is allowed")
    elseif opts.line then
        G.assert(opts.readline_fn)
    elseif not opts.file then
        G.error("One of 'line' or 'file' options is required")
    end

    local tt = Tokenizer.new(opts)
    local par = Parser.new()
    par.tokenizer = tt

    compiler.parse = function(self)
        self.parse_tree = par:all_statements()
        return self.parse_tree
    end
    compiler.typecheck = function(self)
        self.ast = typecheck(self.parse_tree)
        return self.ast
    end
    compiler.specialize = function(self)
        self.specialized_ast = specialize(self.ast)
        return self.specialized_ast
    end
    compiler.codegen = function(self)
        self.code = codegen(self.specialized_ast)
        return self.code
    end

    return compiler
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
