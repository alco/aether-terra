--_token = nil
_next_parse_node = nil

--function startParser(tokens)
    --_token = nil
    --nextToken()
--end

-- synchrounous token get
function nextParseNode()
    local node
    if _next_parse_node ~= nil then
        node = _next_parse_node
        _next_parse_node = nil
    else
        local tok = get_tok_co()
        if tok == nil then
            node = {}
        else
            node = token_to_parse_node(tok)
        end
    end
    return node
end

function putBackNode(node)
    _next_parse_node = node
end

-- asynchrounous token get
function peekParseNode()
    if _next_parse_node == nil then
        local tok = get_tok_co({ async = true })
        if tok then
            _next_parse_node = token_to_parse_node(tok)
        end
    end
    return _next_parse_node
end

function expect(typ)
    if typ == nil then
        if peekParseNode() ~= nil then
            error("Expected end of line. Got "..peekParseNode().id)
        end
        return
    end

    local node = nextParseNode() --peekToken()
    if node == nil then
        error("Expected "..typ) --end of line") -- FIXME  (1 + 2 + \n 3
    elseif node.id ~= typ then
        table_print(node)
        error("Unexpected token "..node.id.."; expected "..typ)
    end
end

function skip(typ)
    expect(typ)
    _next_parse_node = nil
end

--------------------------

local symbol_table = {
    int = { id = "int", lbp = 0, nud = function(self)
        return self
    end },

    float = { id = "float", lbp = 0, nud = function(self)
        return self
    end },

    ident = { id = "ident", lbp = 0, nud = function(self)
        return self
    end },

    string = { id = "string", lbp = 0, nud = function(self)
        return self
    end },

    nl = { id = "newline", lbp = 0 }
}

local function symbol(id, precedence)
    precedence = precedence or 0

    local tab = symbol_table[id]
    if tab then
        tab.lbp = math.max(precedence, tab.lbp)
    else
        tab = {}
        tab.id = id
        tab.lbp = precedence
        symbol_table[id] = tab
    end
    return tab
end

local function prefix(op, precedence)
    local tab = symbol(op)
    tab.nud = function(self)
        self.first = expression(precedence)
        return self
    end
end

local function infix(op, precedence)
    local tab = symbol(op, precedence)
    tab.led = function(self, other)
        self.first = other
        self.second = expression(precedence)
        return self
    end
end

local function infix_r(op, precedence)
    local tab = symbol(op, precedence)
    tab.led = function(self, other)
        self.first = other
        self.second = expression(precedence-1)
        return self
    end
end

function pretty_print(sym)
    if sym.first and sym.second then
        -- binary op
        return "("..sym.id.." "..pretty_print(sym.first).." "..pretty_print(sym.second)..")"
    elseif sym.first then
        -- unary op
        return "("..sym.id.." "..pretty_print(sym.first)..")"
    elseif sym.exprs then
        local str = "("..sym.id
        for _, e in ipairs(sym.exprs) do
            str = str .. " " .. pretty_print(e)
        end
        return str .. ")"
    elseif sym.items then
        local str = "("..sym.id
        for _, e in ipairs(sym.items) do
            str = str .. " " .. pretty_print(e[1]) .. ":" .. pretty_print(e[2])
        end
        return str .. ")"
    elseif sym.id == "string" then
        return "\""..sym.value.."\""
    else
        -- identifier or literal
        --print("bad symbol")
        --table_print(sym)
        return sym.value
    end
end

function make_symbol(typ)
    local sym = {}
    if symbol_table[typ] == nil then
        error("Unrecognized token "..typ)
    end
    for k,v in pairs(symbol_table[typ]) do
        sym[k] = v
    end
    --setmetatable(sym, symbol_table[typ])
    return sym
end

function token_to_parse_node(tok)
    --print("mapping token")
    --table_print(tok)
    local sym
    if tok.type == "operator" then
        sym = make_symbol(tok.value)
    elseif tok.type == "term" then
        sym = make_symbol(tok.value)
    else
        sym = make_symbol(tok.type)
        sym.value = tok.value
    end
    if sym == nil then
        printoken(tok)
        error("Unrecognized token")
    end
    sym.type = tok.type
    return sym
end

--------------------------

--    def expression(self, rbp=0):
--        t = self._token
--        self.advance()
--        left = t.nud()
--        while rbp < self._token.lbp:
--            t = self._token
--            self.advance()
--            left = t.led(left)
--        return left

function expression(rbp)
    rbp = rbp or 0

    local node = nextParseNode()
    --print("Calling nud on")
    --table_print(node)
    --print("---")
    local left = node:nud()
    while peekParseNode() and rbp < peekParseNode().lbp do
        --print("beginloop")
        node = nextParseNode()
        --print("Calling led on")
        --table_print(t)
        --print("---")
        left = node:led(left)
        --print("endloop")
    end
    return left
end

function parse_expr_list_until(term)
    local exprs = {}
    while true do
        if peekParseNode() and peekParseNode().id == term then
            skip(term)
            break
        else
            local node = nextParseNode()
            if node.id == term then
                break
            else
                putBackNode(node)
            end
        end
        --print("adding something to exprs")
        local expr = expression()
        --print(expr.id)
        table.insert(exprs, expr)
    end
    return exprs
end

function parse_keyval_list_until(term)
    local items = {}
    while true do
        if peekParseNode() and peekParseNode().id == term then
            skip(term)
            break
        else
            local node = nextParseNode()
            if node.id == term then
                break
            else
                putBackNode(node)
            end
        end
        local item = parse_keyval_expr()
        table.insert(items, item)
    end
    return items
end

function parse_keyval_expr()
    local node = nextParseNode()
    if not (node.id == "ident" or node.id == "string") then
        error("Bad syntax in map literal. Expected identifier or a string")
    end
    skip(":")  -- make it optional?
    local expr = expression()
    return { node, expr }
end

function advance(typ)
    --if 
    --local expr = 
    --if typ then expect(typ) end
    --return nextToken()
end


------------------------------

infix("+", 10)
infix("-", 10)
infix("*", 20)
infix("/", 20)
infix("•", 20)

infix_r("↑",  30)  -- exponentiation
infix_r("**", 30)  -- exponentiation

-- Unary ops
--prefix("+", 40)
prefix("-", 40)

-- Comparisons
infix("==", 9)
infix("≠",  9)
infix("<",  9)
infix("≤",  9)
infix(">",  9)
infix("≥",  9)

-- TODO: tuples
-- ⟨ ⟩
symbol(")")
symbol("(", 100).nud = function(self)
    -- self is discarded
    local expr = expression()
    skip(")")
    return expr
end

symbol("[", 101)
symbol("]")

-- Array literal
symbol("[").nud = function(self)
    self.id = "array"
    self.exprs = parse_expr_list_until("]")
    return self
end

-- Array subscript
symbol("[").led = function(self, left)
    self.id = "subscript"
    self.first = left
    self.second = expression()
    skip("]")
    return self
end

symbol("{", 101)
symbol("}")
symbol(":")

-- Dict/map
symbol("{").nud = function(self)
    self.id = "map"
    self.items = parse_keyval_list_until("}")
    return self
end

-- Constructor
symbol("{").led = function(self, left)
    self.id = "constructor"
    self.first = left
    self.second = { id = "array", exprs = parse_expr_list_until("}") }
    return self
end

-- Keywords
symbol("var").nud = function(self)
    self.ident = advance("ident")
    return self
end
