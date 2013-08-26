--_token = nil
_next_token = nil

--function startParser(tokens)
    --_token = nil
    --nextToken()
--end

-- synchrounous token get
function nextToken()
    local tok
    if _next_token ~= nil then
        tok = _next_token
        _next_token = nil
    else
        local t = get_tok_co()
        if t == nil then
            tok = {}
        else
            tok = map_token(t)
        end
    end
    return tok
end

-- asynchrounous token get
function peekToken()
    if _next_token == nil then
        local t = get_tok_co({ async = true })
        if t then
            _next_token = map_token(t)
        end
    end
    return _next_token
end

--function advance(typ)
    --if typ then expect(typ) end
    --return nextToken()
--end

function expect(typ)
    if typ == nil then
        if peekToken() ~= nil then
            error("Expected end of line. Got "..peekToken().id)
        end
        return
    end

    local tok = nextToken() --peekToken()
    if tok == nil then
        error("Expected "..typ) --end of line") -- FIXME  (1 + 2 + \n 3
    elseif tok.id ~= typ then
        table_print(tok)
        error("Unexpected token "..tok.id.."; expected "..typ)
    end
end

function skip(typ)
    expect(typ)
    _next_token = nil
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
    else
        -- identifier or literal
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

function map_token(tok)
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

    local t = nextToken()
    --print("Calling nud on")
    --table_print(t)
    --print("---")
    local left = t:nud()
    while peekToken() and rbp < peekToken().lbp do
        --print("beginloop")
        t = nextToken()
        --print("Calling led on")
        --table_print(t)
        --print("---")
        left = t:led(left)
        --print("endloop")
    end
    return left
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
symbol(")", 0)
symbol("(", 100).nud = function(self)
    -- self is discarded
    local expr = expression()
    skip(")")
    return expr
end
