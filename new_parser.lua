------------------------------------
-- ** Aether Expression Parser ** --
------------------------------------

-- import global dependencies
--local coroutine = _G.coroutine
local assert = _G.assert
local error = _G.error
--local io = _G.io
local ipairs = _G.ipairs
local max = _G.math.max
local pairs = _G.pairs
local table = _G.table
--local print = _G.print
--local pcall = _G.pcall
--local require = _G.require

-- Prevent modifications to global environment
local package_env = {}
setfenv(1, package_env)


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
            led = err_led_fn
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
                return "("..self.id.." "..self.first:format()..")"
            end
        }
        return pnode
    end
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
                return "("..self.id.." "..self.first:format().." "..self.second:format()..")"
            end
        }
        return pnode
    end
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

    self:skip_optional_eol()

    local node = self:pullNode()
    if not node or node.id == ";" then
        return node
    end
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
    self:skip_eol()
    return left
end

function parser.all_statements(self, rbp)
    local list = {}
    while self.tokenizer.peekToken() do
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
    local tok = self.tokenizer.pullToken()
    if not tok then
        error("Unexpected end of input")
    end
    return map_token(tok)
end

function parser.peekNode(self)
    local tok = self.tokenizer.peekToken()
    return map_token(tok)
end

function parser.skip_optional_eol(self)
    while true do
        local tok = self.tokenizer.peekToken()
        if not tok then
            break
        end
        if tok.value == "nl" then
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
    if not (tok.value == ";" or tok.value == "nl") then
        error(tok.row..":"..tok.col.." Expected newline or semicolon. Got '"..tok.value.."'")
    end
    self.tokenizer.skip(tok)
end

--
-- Parse node definitions
--

for _, n in ipairs({"int", "float", "ident", "string"}) do
    make_default_node(n)
end

-- Comparisons
make_infix("==", 9)
make_infix("≠",  9)
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
make_infix(":", 25)

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


local null_node = make_node("null")
null_node.format = function(self) return "null" end

make_node(")")

-- Grouping expressions
make_node("gparen").nud = function(self)
    parser:skip_optional_eol()

    local node = parser:pullNode()
    if node.id == ")" then
        return null_node -- should be empty tuple or error instead?
    end
    parser.tokenizer.pushToken()

    local expr = parser:expression() -- FIXME: need ot be statement
    parser:skip_optional_eol()
    parser.tokenizer.skip(")")
    return expr

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

-- Funcalls
make_node("cparen", 1).led = function(self, left)
    local pnode = {
        id = "funcall",
        name = left,
        args = {parser:expression()}, --parse_expr_list_until(")")
        format = function(self)
            local argstr = ""
            for _, expr in ipairs(self.args) do
                argstr = argstr.." "..expr:format()
            end
            return "(funcall "..self.name:format()..argstr..")"
        end
    }
    parser.tokenizer.skip(")")
    return pnode
end

-- Assignment
-- FIXME: turn it into statement
make_infix("=", 1)

-- Variable declaration
make_node("var").nud = function(self)
    local pnode = {}
    local expr = parser:expression()  -- FIXME: prevent `var (123; a = 1)`
    if expr.id == "ident" then
        pnode.first = expr
    elseif expr.id == "=" then
        pnode.first = expr.first
        pnode.second = expr.second
    else
        error("Bad variable definition")
    end
    pnode.format = function(self)
        local str = "(var "..self.first:format()
        if self.second then
            str = str.." "..self.second:format()
        end
        str = str..")"
        return str
    end
    return pnode
end

-- Conditional
make_node("if").nud = function(self)
    local pnode = {
        id = "if",
        cond = parser:expression(),
        thenclause = parser:expression()
    }
    if parser.tokenizer.peekToken() and parser.tokenizer.peekToken().value == "else" then
        parser.tokenizer.skip("else")
        pnode.elseclause = parser:expression()
    end
    pnode.format = function(self)
        local str = "(if "..self.cond:format().." "..self.thenclause:format()
        if self.elseclause then
            str = str.." "..self.elseclause:format()
        end
        str = str..")"
        return str
    end
    return pnode
end

-- Function literal
make_node("fn").nud = function(self)
    local pnode = {
        id = "fn"
    }

    local node = parser:pullNode()
    if node.id == "cparen" then
        -- function literal
        pnode.args = {parser:expression()} --parse_expr_list_until(")")
        parser.tokenizer.skip(")")
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
        error("Bad function definition")
    end
    pnode.format = function(self)
        local head
        if self.head then
            head = self.head:format()
        end
        local args
        if self.args then
            args = "("
            for i, arg in ipairs(self.args) do
                args = args..arg:format()
                if i < #self.args then
                    args = args.." "
                end
            end
            args = args..")"
        end
        local str = "(fn"
        if head then
            str = str.." "..head
        end
        if args then
            str = str.." "..args
        end
        if self.body then
            str = str.." "..self.body:format()
        end
        str = str..")"
        return str
    end
    return pnode
end

return parser
