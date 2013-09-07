------------------------------------
-- ** Aether Expression Parser ** --
------------------------------------

-- import global dependencies
--local coroutine = _G.coroutine
local error = _G.error
--local io = _G.io
local ipairs = _G.ipairs
local max = _G.math.max
local pairs = _G.pairs
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

--
-- Parse node definitions
--

for _, n in ipairs({"int", "float", "ident", "string"}) do
    make_default_node(n)
end

make_infix("=", 1)

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
    error("Unrecognized token '"..tok.type.."'")
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
    return map_token(tok)
end

function parser.peekNode(self)
    local tok = self.tokenizer.peekToken()
    return map_token(tok)
end

return parser
