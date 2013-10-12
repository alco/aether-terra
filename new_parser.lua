-----------------------------------
-- ** Aether Parser Framework ** --
-----------------------------------

-- Prevent modifications to global environment
local G = _G
local package_env = {}
setfenv(1, package_env)

Util = G.require("util")

val_fn = function(self)
    return self.value
end
id_fn = function(self)
    return {
        id = self.id,
        value = self.tok.value,
        format = val_fn,

        -- used to rewrite placeholder arguments in anonymous functions
        visit = function(self, visitor)
            visitor(self)
        end,
    }
end
err_nud_fn = function(self)
    Util.error("Trying to use '"..self.id.."' in prefix position.")
end
err_led_fn = function(self, left)
    Util.error("Trying to use '"..self.id.."' in infix position after '"..left.id.."'.")
end
err_snud_fn = function(self)
    Util.error("Trying to use '"..self.id.."' in statement position.")
end
err_sled_fn = function(self, left)
    Util.error("Trying to use '"..self.id.."' in statement position after '"..left.id.."'.")
end


function new()
    local node_table = {}
    local parser = { node_table = node_table }

    function parser.make_default_node(id)
        local node = {
            id = id,
            lbp = 0,
            nud = id_fn,
            snud = id_fn,
            led = err_led_fn
        }
        node_table[id] = node
        return node
    end

    function parser.make_node(id, precedence)
        precedence = precedence or 0

        local node = node_table[id]
        if node then
            node.lbp = Util.max(precedence, node.lbp)
        else
            node = {
                id = id,
                lbp = precedence,
                nud = err_nud_fn,
                led = err_led_fn,
                snud = err_snud_fn,
                sled = err_sled_fn
            }
            node_table[id] = node
        end
        return node
    end

    function parser.make_prefix(op, precedence, other_id)
        local node = parser.make_node(op, precedence)
        node.nud = function(self)
            local pnode = {
                id = other_id or self.id,
                first = parser:expression(precedence),
                format = function(self)
                    return Util.strformat("({1} {2})", op, self.first:format())
                end,
                visit = function(self, visitor)
                    visitor(self)
                    self.first:visit(visitor)
                end,
            }
            return pnode
        end
        node.snud = node.nud
        return node
    end

    local function _make_infix_common(op, precedence, new_pred)
        local node = parser.make_node(op, precedence)
        node.led = function(self, other)
            local pnode = {
                id = self.id,
                first = other,
                second = parser:expression(new_pred),
                format = function(self)
                    return Util.strformat("({1} {2} {3})", self.id, self.first:format(), self.second:format())
                end,
                visit = function(self, visitor)
                    visitor(self)
                    self.first:visit(visitor)
                    self.second:visit(visitor)
                end,
            }
            return pnode
        end
        node.sled = node.led
        return node
    end

    function parser.make_infix(op, precedence)
        return _make_infix_common(op, precedence, precedence)
    end

    function parser.make_infix_r(op, precedence)
        return _make_infix_common(op, precedence, precedence-1)
    end

    --
    -- Parser driver
    function parser.expression(self, rbp)
        rbp = rbp or 0

        local node = self:pullNode()
        --print("Calling nud on")
        --table_print(node)
        --print("---")
        local left = node:nud()
        while self:peekNode() and rbp < self:peekNode().lbp do
            --print("beginloop")
            node = self:pullNode()
            --print("Calling led on")
            --table_print(t)
            --print("---")
            left = node:led(left)
            --print("endloop")
        end
        return left
    end

    function parser.statement(self, rbp, dont_skip_eol)
        rbp = rbp or 0

        -- May be an empty statement, so we don't pull
        self:skip_optional_eol()
        local node = self:peekNode()
        if not node then
            G.assert(self.tokenizer.atEOF())
            return
        end
        if node.id == ";" then
            return self:pullNode()
        end

        self:pullNode()
        --G.print("Calling nud on "..node.id)
        --print("---")
        local left = node:snud()
        while self:peekNode() and rbp < self:peekNode().lbp do
            --print("beginloop")
            node = self:pullNode()
            --G.print("Calling led on "..node.id)
            --print("---")
            left = node:sled(left)
            --print("endloop")
        end

        if not dont_skip_eol then
            --G.print("Calling skip eol")
            local terminator = self:skip_eol()
            if terminator == ";" then
                left.isstatement = true
            end
        else
            --G.print("__Skipping Calling skip eol")
        end

        return left
    end

    function parser.all_statements(self, rbp)
        local list = {}
        while self.tokenizer.pullToken() do
            self.tokenizer.pushToken()

            local stat = self:statement(rbp)
            if stat then
                G.table.insert(list, stat)
            else
                G.assert(self.tokenizer.atEOF())
                break
            end
        end
        return list
    end

    --

    local function new_node(tok, id)
        local node = {}
        for k, v in G.pairs(node_table[id]) do
            node[k] = v
        end
        node.tok = tok
        --setmetatable(node, node_table[typ])
        return node
    end

    local function token_to_node(tok)
        if tok.type ~= "string" and node_table[tok.value] then
            -- it's a keyword
            return new_node(tok, tok.value)
        elseif node_table[tok.type] then
            return new_node(tok, tok.type)
        end
        Util.error(tok.row..":"..tok.col..": Behavior not defined for token '"..tok.value.."'")
    end

    local function map_token(tok)
        local node
        if tok then
            node = token_to_node(tok)
        end
        if not node and tok then
            Util.error("Bad token '"..tok.type.."'")
        end
        return node
    end

    function parser.pullNode(self)
        self:skip_optional_eol()

        local tok = self.tokenizer.pullToken()
        if not tok then
            Util.error("Unexpected end of input")
        end
        return map_token(tok)
    end

    function parser.peekNode(self, value)
        local tok = self.tokenizer.peekToken()
        return map_token(tok)
    end

    function parser.peekToken(self, value)
        local tok = self.tokenizer.peekToken()
        if value then
            return tok and tok.value == value
        end
    end

    function parser.peekAndSkip(self, value)
        if self:peekToken(value) then
            self:skip(value)
            return true
        end
    end

    function parser.pullAndSkip(self, value)
        local node = self:pullNode()
        if node and node.id == value then
            return true
        end
        self.tokenizer.pushToken()
    end

    function parser.advance(self, id)
        local node = self:pullNode()
        if node.id ~= id then
            Util.error("Unexpected '"..node.id.."'. Expected '"..id.."'")
        end
        return node
    end

    function parser.skip(self, tok)
        self:skip_optional_eol()
        self.tokenizer.skip(tok)
    end

    function parser.skip_optional_eol(self)
        while true do
            local tok = self.tokenizer.peekToken()
            if tok and tok.value == "nl" then
                self.tokenizer.skip(tok)
            else
                break
            end
        end
    end

    function parser.skip_eol(self)
        --G.print(G.debug.traceback())
        local tok = self.tokenizer.peekToken()
        if not tok then
            return
        end
        if not (tok.value == ";" or tok.value == "nl" or tok.value == ")") then
            Util.error(tok.row..":"..tok.col.." Expected newline or semicolon. Got '"..tok.value.."'")
        end
        if tok.value ~= ")" then
            self.tokenizer.skip(tok)
            return tok.value
        end
    end

    --

    function parser.is_statement(expr)
        return expr.isstatement or expr.id == "var" or expr.id == "=" or expr.id == ";"
    end

    function parser.is_literal(expr)
        return expr.id == "int" or expr.id == "float" or expr.id == "string"
    end

    local function check_simple_expr(expr)
        if not (parser.is_literal(expr) or expr.id == "ident") or expr.parenthesised then
            local fmt
            if expr.parenthesised then
                fmt = "("..expr:format()..")"
            else
                fmt = expr:format()
            end
            Util.error("Expected a literal or identifier. Got '"..fmt.."'")
        end
    end

    function parser.var_list_with_sep(self, sep)
        -- One element is
        -- a
        --   OR
        -- a = 1
        --   OR
        -- a: int
        --   OR
        -- a: int = 1
        local pnode = {
            id = "varlist",
            vars = {},
            format = function(self)
                return Util.strjoin(Util.map_format(self.vars))
            end
        }

        while true do
            local vnode = {
                id = "defvar",
                format = function(self)
                    local typ = ""
                    if self.typ then
                        typ = ":"..self.typ:format()
                    end
                    local val = ""
                    if self.value then
                        val = " "..self.value:format()
                    end
                    return Util.strformat("({1}{2}{3})", self.name:format(), typ, val)
                end
            }
            vnode.name = self:advance("ident"):nud()
            if self:peekAndSkip(":") then
                vnode.typ = self.type_parser:expression()
            end
            if self:peekAndSkip("=") then
                vnode.value = self:expression()
            end
            G.table.insert(pnode.vars, vnode)

            if not self:peekAndSkip(sep) then
                break
            end
        end

        return pnode
    end

    function parser.expr_list_until(self, term)
        -- ()
        --   OR
        -- (a b c)
        --   OR
        -- (a 1 "abc")
        --   OR
        -- (1+2, a, b)
        --
        local pnode = {
            id = "exprlist",
            exprs = {},
            format = function(self)
                return Util.strformat("({1})", Util.strjoin(Util.map_format(self.exprs)))
            end
        }

        -- Simple case of zero expressions
        local node = self:pullNode()
        if node.id == term then
            return pnode
        else
            self.tokenizer.pushToken()
        end

        local expr = self:expression()
        G.table.insert(pnode.exprs, expr)

        -- Before validating the first expression, see if we're dealing with commas
        -- here
        local parsing_commas = false
        node = self:pullNode()
        if node.id == term then
            return pnode
        elseif node.id == "," then
            parsing_commas = true
        end
        self.tokenizer.pushToken()

        -- If no comma was found, only simple expressions are allowed
        if not parsing_commas then
            check_simple_expr(expr)
        end

        while true do
            node = self:pullNode()
            if node.id == term then
                break
            elseif parsing_commas and node.id == "," then
                -- simply skipping the comma
            else
                self.tokenizer.pushToken()
            end
            local expr = self:expression()
            if not parsing_commas then
                check_simple_expr(expr)
            end
            G.table.insert(pnode.exprs, expr)
        end

        return pnode
    end

    local function slice_right(self)
        local node = self:pullNode()
        self.tokenizer.pushToken()
        if node.id == "]" then
            return nil
        end
        return self:expression()
    end

    function parser.slice_expr(self)
        local pnode = {
            id = "slice",
            format = function(self)
                if self.both_ends then
                    local first = "_"
                    if self.first then
                        first = self.first:format()
                    end
                    local second = "_"
                    if self.second then
                        second = self.second:format()
                    end
                    return Util.strformat("(: {1} {2})", first, second)
                else
                    local first = "[]"
                    if self.first then
                        first = "["..self.first:format().."]"
                    end
                    return first
                end
            end
        }

        local node = self:pullNode()
        if node.id == "]" then
            return pnode
        end

        if node.id ~= ":" then
            self.tokenizer.pushToken()
            pnode.first = self:expression()
            node = self:pullNode()
        end

        if node.id == ":" then
            pnode.both_ends = true
            pnode.second = slice_right(self)
        else
            self.tokenizer.pushToken()
        end
        self:skip("]")

        return pnode
    end

    local symnumber = 1
    local function gensym()
        local str = "sym#"..symnumber
        symnumber = symnumber + 1
        return str
    end

    local function mapsym(sym, map)
        local val = map[sym]
        if not val then
            val = gensym()
            map[sym] = val
            G.table.insert(map.order, val)
        end
        return val
    end

    local function _extract_args(expr, map)
        expr:visit(function(self)
            if self.id == "ident" and (self.value == "➀" or self.value == "➁" or self.value == "➂") then
                self.value = mapsym(self.value, map)
            end
        end)
    end

    function parser.extract_anonymous_args(expr)
        local argmap = {order = {}}
        _extract_args(expr, argmap)
        return argmap.order
    end

    return parser
end

return {
    new = new
}
