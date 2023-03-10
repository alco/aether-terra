--------------------------------------------------
-- ** Aether Statement and Expression Parser ** --
--------------------------------------------------

-- Prevent modifications to global environment
local G = _G
local package_env = {}
setfenv(1, package_env)

ParserBase = G.require("new_parser")
TypeParser = G.require("type_parser")
Util = G.require("util")

--
-- Parse node definitions
--

function new()
    local parser = ParserBase.new()
    local type_parser = TypeParser.new(parser)
    parser.type_parser = type_parser  -- TODO: think about this

    local make_node = parser.make_node
    local make_prefix = parser.make_prefix
    local make_infix = parser.make_infix
    local make_infix_r = parser.make_infix_r

    function make_pow(op, pow, precedence)
        local node = parser.make_node(op, precedence)
        local powstr = G.tostring(pow)
        node.led = function(self, left)
            local pnode = {
                id = "**",
                first = left,
                second = { id = "int", value = powstr, format = function(self) return powstr end },
                format = function(self)
                    return Util.strformat("(** {1} {2})", self.first:format(), powstr)
                end,
                visit = function(self, visitor)
                    visitor(self)
                    self.first:visit(visitor)
                end
            }
            return pnode
        end
        node.sled = node.led
        return node
    end

    ---

    for _, n in G.ipairs({"int", "float", "ident", "true", "false"}) do
        parser.make_default_node(n)
    end

    make_node("string").nud = function(self)
        return {
            id = self.id,
            value = self.tok.value,
            format = function(self)
                return Util.strformat("\"{1}\"", self.value)
            end
        }
    end
    make_node("string").snud = make_node("string").nud

    -- Comparisons
    make_infix("or", 6)
    make_infix("and", 7)

    make_infix("in", 8)
    make_node("..", 8).led = function(self, other)
        local pnode = {
            id = self.id,
            first = other,
            format = function(self)
                local second = self.second and self.second:format() or "_"
                return Util.strformat("({1} {2} {3})", self.id, self.first:format(), second)
            end,
            visit = function(self, visitor)
                visitor(self)
                self.first:visit(visitor)
                self.second:visit(visitor)
            end,
        }
        local tok = parser.tokenizer.peekToken()
        if not tok then
            Util.error("Suffix .. cannot be used outside of function call")
        end
        if tok.value ~= ")" then
            pnode.second = parser:expression(8)
        end
        return pnode
    end
    make_node("..").sled = make_node("..").led


    make_infix("==", 8)
    make_infix("???",  8)
    make_infix("<",  9)
    make_infix("???",  9)
    make_infix(">",  9)
    make_infix("???",  9)

    -- Arithmetic
    make_infix("+", 10)
    make_infix("-", 10)
    make_infix("*", 20)
    make_infix("/", 20)
    make_infix("mod", 20)
    make_infix("???", 20)

    -- Bitwise
    make_infix("<<", 20)
    make_infix(">>", 20)
    make_infix("band", 20)
    make_infix("bor", 20)

    -- Stream operators
    make_infix("->", 7)

    -- Keywords
    make_node("break").snud = function(self)
        return {
            id = "break",
            format = function(self) return "break" end
        }
    end

    -- Unary ops
    make_prefix("-", 30, "neg").lbp = 10

    -- Exponentiation
    make_infix_r("???",  40)
    make_infix_r("**", 40)
    make_pow("??", 2, 40)
    make_pow("??", 3, 40)


    -- Terminals
    make_node("nl")
    make_node(";").format = function(self)
        return ";"
    end
    make_node(",")

    --local null_node = make_node("null")
    --null_node.format = function(self) return "null" end

    make_node(")")

    -- Grouping expressions
    make_node("gparen").nud = function(self)
        local pnode = {
            id = "block",
            stats = {},
            format = function(self)
                local stats = ""
                if #self.stats > 0 then
                    stats = " "..Util.strjoin(Util.map_format(self.stats))
                end
                return Util.strformat("(block{1})", stats)
            end
        }

        if parser:pullAndSkip(")") then
            return pnode
        end

        local stat = parser:statement()
        G.table.insert(pnode.stats, stat)

        if parser:pullAndSkip(")") then
            if parser.is_statement(stat) then
                return pnode
            else
                stat.parenthesised = true
                return stat
            end
        end

        -- At this point we are sure that we're parsing a block
        -- and not a parenthesised expression
        while true do
            if parser:pullAndSkip(")") then
                break
            end
            G.table.insert(pnode.stats, parser:statement())
        end

        return pnode
    end
    make_node("cparen").nud = make_node("gparen").nud
    make_node("gparen").snud = make_node("gparen").nud
    make_node("cparen").snud = make_node("gparen").snud

    -- Vectors
    make_node("???")
    make_node("???").nud = function(self)
        local pnode = {
            id = "vector",
            args = parser:expr_list_until("???"),
            format = function(self)
                return Util.strformat("(vector {1})", self.args:format())
            end
        }
        return pnode
    end
    make_node("???").snud = make_node("???").nud

    -- Funcalls
    make_node("cparen", 100).led = function(self, left)
        local pnode = {
            id = "funcall",
            name = left,
            args = parser:expr_list_until(")"),
            format = function(self)
                return Util.strformat("(funcall {1} {2})", self.name:format(), self.args:format())
            end
        }
        return pnode
    end
    make_node("cparen").sled = make_node("cparen").led

    -- Assignment
    make_node("=", 1).sled = function(self, left)
        return {
            id = "=",
            name = left,
            value = parser:expression(),
            format = function(self)
                return Util.strformat("(= {1} {2})", self.name:format(), self.value:format())
            end
        }
    end
    make_node("=").led = function(self, left)
        Util.error("Unable to use '=' in expression")
    end

    -- Variable declaration
    make_node("var").snud = function(self)
        local pnode = {
            id = "var",
            varlist = parser:var_list_with_sep(","),
            format = function(self)
                return Util.strformat("(var {1})", self.varlist:format())
            end
        }

        local tok = parser.tokenizer.peekToken()
        if tok and tok.value ~= "nl" and tok.value ~= ";" and tok.value ~= ")" and tok.value ~= "in" then -- FIXME: too complicated
            -- try to parse the type spec
            local typ = type_parser:expression()
            for _, v in G.ipairs(pnode.varlist.vars) do
                -- FIXME: what about "var a:int string"?
                v.typ = typ
            end
        end

        return pnode
    end

    -- Conditional
    make_node("if").nud = function(self)
        local pnode = {
            id = "if",
            cond = parser:expression()
            --thenclause = parser:expression()
        }
        local tok = parser.tokenizer.peekToken()
        if not tok or tok.value == "nl" or tok.value == ";" then
            Util.error(self.tok.row..":"..self.tok.col.." Expected then-clause to begin on the same line")
        end

        pnode.thenclause = parser:expression()
        if parser:peekAndSkip("else") then
            -- FIXME: it's still possible to move expressions over to the next line
            pnode.elseclause = parser:expression()
        end
        pnode.format = function(self)
            local elseclause = ""
            if self.elseclause then
                elseclause = " "..self.elseclause:format()
            end
            return Util.strformat("(if {1} {2}{3})", self.cond:format(), self.thenclause:format(), elseclause)
        end
        return pnode
    end
    make_node("if").snud = make_node("if").nud

    -- For loop
    make_node("for").snud = function(self)
        local pnode = {
            id = "for",
            head = parser:statement(nil, true),  -- don't skip newline here before the next statement
            body = parser:statement(nil, true),  -- don't skip newline, "for" will take care of that
            format = function(self)
                return Util.strformat("(for {1} {2})", self.head:format(), self.body:format())
            end
        }
        return pnode
    end

    -- Function literal
    function parse_shortfuct_function(pnode)
        pnode.body = parser:expression()
        pnode.args = {
            id = "exprlist",
            exprs = parser.extract_anonymous_args(pnode.body),
            format = function(self)
                return Util.strformat("({1})", Util.strjoin(Util.map_format(self.exprs)))
            end
        }
    end

    function make_function_literal_stub()
        return {
            id = "fn",
            format = function(self)
                local head = ""
                if self.head then
                    head = " "..self.head:format()
                end

                local body = ""
                if self.body then
                    body = " "..self.body:format()
                end

                return Util.strformat("(fn {1}{2}{3})", head, self.args:format(), body)
            end
        }
    end

    make_node("???")
    make_node("???").nud = function(self)
        local pnode = make_function_literal_stub()
        parse_shortfuct_function(pnode)
        parser:skip("???")
        return pnode
    end
    make_node("???").snud = make_node("???").nud

    make_node("::")

    make_node("fn").nud = function(self)
        local pnode = make_function_literal_stub()

        local node = parser:pullNode()
        if node.id == "cparen" then
            -- function literal
            pnode.args = parser:expr_list_until(")")
            if parser:peekAndSkip("::") then
                pnode.typ = type_parser:expression()
            end
            pnode.body = parser:expression()
        else
            -- short function literal
            parser.tokenizer.pushToken()

            parse_shortfuct_function(pnode)
        end
        return pnode
    end
    make_node("fn").snud = make_node("fn").nud

    make_node("def").snud = function(self)
        local pnode = {
            id = "def",
            format = function(self)
                local body = ""
                if self.body then
                    body = " "..self.body:format()
                end
                return Util.strformat("(def {1}{2}{3})", self.name.tok.value, self.args:format(), body)
            end
        }

        pnode.name = parser:advance("ident")
        parser:advance("cparen")
        pnode.args = parser:expr_list_until(")")

        if parser:peekAndSkip("::") then
            local type_expr = type_parser:expression()
        end

        if parser:peekNode() then
            pnode.body = parser:expression()
        end

        return pnode
    end

    make_node("]")

    -- Array literal
    make_node("[").nud = function(self)
        local pnode = {
            id = "array",
            exprs = parser:expr_list_until("]"),
            format = function(self)
                return Util.strformat("(array {1})", self.exprs:format())
            end
        }
        return pnode
    end
    make_node("[").snud = make_node("[").nud

    make_node(":")

    make_infix("as", 50)
    --make_node(":", 50).led = function(self, left)
        --local pnode = {
            --id = "typecast",
            --first = left,
            --second = type_parser:expression(),
            --format = function(self)
                --return Util.strformat("({1} {2} {3})", self.id, self.first:format(), self.second:format())
            --end,
            --visit = function(self, visitor)
                --visitor(self)
                --self.first:visit(visitor)
                --self.second:visit(visitor)
            --end
        --}
        --return pnode
    --end
    --make_node(":").sled = make_node(":").led

    -- Array subscript
    make_node("[", 30).led = function(self, left)
        local pnode = {
            id = "subscript",
            first = left,
            second = parser:slice_expr(),
            format = function(self)
                return Util.strformat("(subscript {1} {2})", self.first:format(), self.second:format())
            end
        }
        return pnode
    end
    make_node("[").sled = make_node("[").led

    return parser
end

return {
    new = new
}
