------------------------------------
-- ** Aether Expression Parser ** --
------------------------------------

-- import global dependencies
--local coroutine = _G.coroutine
local assert = _G.assert
local gerror = _G.error
--local io = _G.io
local ipairs = _G.ipairs
local max = _G.math.max
local pairs = _G.pairs
local select = _G.select
local table = _G.table
--local print = _G.print
--local pcall = _G.pcall
--local require = _G.require

-- Prevent modifications to global environment
local package_env = {}
setfenv(1, package_env)


--
-- Utility functions
function error(str)
    gerror(str, 0)
end

function table.pack(...)
  return { n = select("#", ...), ... }
end

function map_format(list)
    local new_list = {}
    for _, v in ipairs(list) do
        table.insert(new_list, v:format())
    end
    return new_list
end

function strjoin(list, sep)
    sep = sep or " "

    local str = ""
    for i, v in ipairs(list) do
        str = str..v
        if i < #list then
            str = str..sep
        end
    end
    return str
end

function strformat(fmt, ...)
    local str = fmt
    local args = table.pack(...)
    for i = 1, args.n do
        str = str:gsub("{"..i.."}", args[i])
    end
    return str
end
--

val_fn = function(self)
    return self.value
end
id_fn = function(self)
    return { id = self.id, value = self.tok.value, format = val_fn }
end
err_nud_fn = function(self)
    error("Trying to use '"..self.id.."' in prefix position.")
end
err_led_fn = function(self, left)
    error("Trying to use '"..self.id.."' in infix position after '"..left.id.."'.")
end
err_snud_fn = function(self)
    error("Trying to use '"..self.id.."' in statement position.")
end
err_sled_fn = function(self, left)
    error("Trying to use '"..self.id.."' in statement position after '"..left.id.."'.")
end


node_table = {
    --nl = { id = "newline", lbp = 0 },
    --[";"] = { id = ";", lbp = 0 }
}

--

parser = {}

--

function make_default_node(id)
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

function make_node(id, precedence)
    precedence = precedence or 0

    local node = node_table[id]
    if node then
        node.lbp = max(precedence, node.lbp)
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

function make_prefix(op, precedence)
    local node = make_node(op)
    node.nud = function(self)
        local pnode = {
            id = self.id,
            first = parser:expression(precedence),
            format = function(self)
                return strformat("({1} {2})", self.id, self.first:format())
            end
        }
        return pnode
    end
    node.snud = node.nud
    return node
end

function _make_infix_common(op, precedence, new_pred)
    local node = make_node(op, precedence)
    node.led = function(self, other)
        local pnode = {
            id = self.id,
            first = other,
            second = parser:expression(new_pred),
            format = function(self)
                return strformat("({1} {2} {3})", self.id, self.first:format(), self.second:format())
            end
        }
        return pnode
    end
    node.sled = node.led
    return node
end

function make_infix(op, precedence)
    return _make_infix_common(op, precedence, precedence)
end

function make_infix_r(op, precedence)
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

function parser.statement(self, rbp)
    rbp = rbp or 0

    -- May be an empty statement, so we don't pull
    self:skip_optional_eol()
    local node = self:peekNode()
    if not node then
        assert(self.tokenizer.atEOF())
        return
    end
    if node.id == ";" then
        return self:pullNode()
    end

    self:pullNode()
    --print("Calling nud on")
    --table_print(node)
    --print("---")
    local left = node:snud()
    while self:peekNode() and rbp < self:peekNode().lbp do
        --print("beginloop")
        node = self:pullNode()
        --print("Calling led on")
        --table_print(t)
        --print("---")
        left = node:sled(left)
        --print("endloop")
    end

    local terminator = self:skip_eol()
    if terminator == ";" then
        left.isstatement = true
    end

    return left
end

function parser.all_statements(self, rbp)
    local list = {}
    while self.tokenizer.pullToken() do
        self.tokenizer.pushToken()

        local stat = self:statement(rbp)
        if stat then
            table.insert(list, stat)
        else
            assert(self.tokenizer.atEOF())
            break
        end
    end
    return list
end

--

function new_node(tok, id)
    local node = {}
    for k, v in pairs(node_table[id]) do
        node[k] = v
    end
    node.tok = tok
    --setmetatable(node, node_table[typ])
    return node
end

function token_to_node(tok)
    if node_table[tok.value] then
        -- it's a keyword
        return new_node(tok, tok.value)
    elseif node_table[tok.type] then
        return new_node(tok, tok.type)
    end
    error(tok.row..":"..tok.col..": Unrecognized token '"..tok.value.."'")
end

function map_token(tok)
    local node
    if tok then
        node = token_to_node(tok)
    end
    if not node and tok then
        error("Bad token '"..tok.type.."'")
    end
    return node
end

function parser.pullNode(self)
    self:skip_optional_eol()

    local tok = self.tokenizer.pullToken()
    if not tok then
        error("Unexpected end of input")
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
        error("Unexpected '"..node.id.."'. Expected '"..id.."'")
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
    local tok = self.tokenizer.peekToken()
    if not tok then
        return
    end
    if not (tok.value == ";" or tok.value == "nl" or tok.value == ")") then
        error(tok.row..":"..tok.col.." Expected newline or semicolon. Got '"..tok.value.."'")
    end
    if tok.value ~= ")" then
        self.tokenizer.skip(tok)
        return tok.value
    end
end


function is_statement(expr)
    return expr.isstatement or expr.id == "var" or expr.id == "="
end

function is_literal(expr)
    return expr.id == "int" or expr.id == "float" or expr.id == "string"
end

function check_simple_expr(expr)
    if not (is_literal(expr) or expr.id == "ident") or expr.parenthesised then
        local fmt
        if expr.parenthesised then
            fmt = "("..expr:format()..")"
        else
            fmt = expr:format()
        end
        error("Expected a literal or identifier. Got '"..fmt.."'")
    end
end

function parser.expr_list_until(self, term)
    local pnode = {
        id = "exprlist",
        exprs = {},
        format = function(self)
            return strformat("({1})", strjoin(map_format(self.exprs)))
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
    table.insert(pnode.exprs, expr)

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
        table.insert(pnode.exprs, expr)
    end

    return pnode
end

--
-- Parse node definitions
--

for _, n in ipairs({"int", "float", "ident", "string"}) do
    make_default_node(n)
end
make_node("string").nud = function(self)
    return {
        id = self.id,
        value = self.tok.value,
        format = function(self)
            return strformat("\"{1}\"", self.value)
        end
    }
end
make_node("string").snud = make_node("string").nud

-- Comparisons
make_infix("==", 8)
make_infix("≠",  8)
make_infix("<",  9)
make_infix("≤",  9)
make_infix(">",  9)
make_infix("≥",  9)

-- Arithmetic
make_infix("+", 10)
make_infix("-", 10)
make_infix("*", 20)
make_infix("/", 20)
make_infix("•", 20)

-- Key-value pair
--make_infix(":", 25)

-- Unary ops
make_prefix("-", 30)

-- Exponentiation
make_infix_r("↑",  40)  -- exponentiation
make_infix_r("**", 40)  -- exponentiation

-- Terminals
make_node("nl")
make_node(";").format = function(self)
    return ";"
end
make_node(",")


local null_node = make_node("null")
null_node.format = function(self) return "null" end

make_node(")")

-- Grouping expressions
make_node("gparen").nud = function(self)
    local pnode = {
        id = "block",
        stats = {},
        format = function(self)
            return strformat("(block {1})", strjoin(map_format(self.stats)))
        end
    }

    if parser:pullAndSkip(")") then
        return pnode
    end

    local stat = parser:statement()
    table.insert(pnode.stats, stat)

    if parser:pullAndSkip(")") then
        if is_statement(stat) then
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
        table.insert(pnode.stats, parser:statement())
    end

    return pnode

    --local exprs = {expression()}
    ----print("Got expr")
    ----print(pretty_print(exprs[1]))

    --while true do
        --local at_least_one_semicolon = false
--::continue::
        --local node = nextParseNode()
        --if node.id == ";" then
            --at_least_one_semicolon = true
            --goto continue
        --elseif node.id == ")" then
            --break
        --end

        --if not at_least_one_semicolon then
            --error("semicolon expected")
        --end

        --putBackNode(node)
        --local expr = expression()
        --table.insert(exprs, expr)

        ----print("Got expr")
        ----print(pretty_print(expr))
    --end
    --return {
        --type="block", id="block", exprs=exprs,
        --pretty_print = function(self)
            --local argstr = ""
            --for _, expr in ipairs(self.exprs) do
                --argstr = argstr .. " " .. expr:pretty_print()
            --end
            --return "(block"..argstr..")"
        --end
    --}
end
make_node("cparen").nud = make_node("gparen").nud
make_node("gparen").snud = make_node("gparen").nud
make_node("cparen").snud = make_node("gparen").snud

-- Funcalls
make_node("cparen", 1).led = function(self, left)
    local pnode = {
        id = "funcall",
        name = left,
        args = parser:expr_list_until(")"),
        format = function(self)
            return strformat("(funcall {1} {2})", self.name:format(), self.args:format())
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
            return strformat("(= {1} {2})", self.name:format(), self.value:format())
        end
    }
end
make_node("=").led = function(self, left)
    error("Unable to use '=' in expression")
end

-- Variable declaration
make_node("var").snud = function(self)
    local pnode = {}
    pnode.name = parser:advance("ident"):nud()

    if parser:peekAndSkip("=") then
        pnode.value = parser:expression()
    end
    --error("Bad variable definition")
    pnode.format = function(self)
        local value = ""
        if self.value then
            value = " "..self.value:format()
        end
        return strformat("(var {1}{2})", self.name:format(), value)
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
        error(self.tok.row..":"..self.tok.col.." Expected then-clause to begin on the same line")
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
        return strformat("(if {1} {2}{3})", self.cond:format(), self.thenclause:format(), elseclause)
    end
    return pnode
end
make_node("if").snud = make_node("if").nud

-- Function literal
make_node("fn").nud = function(self)
    local pnode = {
        id = "fn"
    }

    local node = parser:pullNode()
    if node.id == "cparen" then
        -- function literal
        pnode.args = parser:expr_list_until(")")
        pnode.body = parser:expression()
    elseif node.id == "ident" then
        ---- function definition
        --putBackNode(node)

        --local expr = expression()
        ----print(pretty_print(expr))
        --if expr.id ~= "funcall" then
            --error("Expected a function declaration")
        --end
        --self.head = expr
        ----if peekParseNode() and peekParseNode().id == "::" then
            ----self.sig = expression()
        ----end
        --self.body = expression()
    else
        error(self.tok.row..":"..self.tok.col.." Bad function definition")
    end
    pnode.format = function(self)
        local head = ""
        if self.head then
            head = " "..self.head:format()
        end

        local body = ""
        if self.body then
            body = " "..self.body:format()
        end

        return strformat("(fn {1}{2}{3})", head, self.args:format(), body)
    end
    return pnode
end

return parser
