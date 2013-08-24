--_token = nil
_next_token = nil

--function startParser(tokens)
    --_token = nil
    --nextToken()
--end

function nextToken()
    local tok
    if _next_token ~= nil then
        tok = _next_token
        _next_token = nil
    else
        tok = map_token(get_tok_co())
    end
    return tok
end

function peekToken()
    if _next_token == nil then
        _next_token = map_token(get_tok_co())
    end
    return _next_token
end

--function advance(typ)
    --if typ then expect(typ) end
    --return nextToken()
--end

function expect(typ)
    if _token.type ~= typ then
        error("Unexpected token ".._token.type.."; expected "..typ)
    end
end

--------------------------

local symbol_table = {
    int = { lbp = 0, nud = function(self)
        return self
    end },

    float = { lbp = 0, nud = function(self)
        return self
    end },

    ident = { lbp = 0, nud = function(self)
        return self
    end },

    nl = { lbp = 0 },

    ["+"] = { lbp = 10, led = function(self, other)
        self.first = other
        self.second = expression(self.lbp)
        return self
    end }
}

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
    print("Calling nud on")
    table_print(t)
    print("---")
    local left = t:nud()
    while rbp < peekToken().lbp do
        --print("beginloop")
        t = nextToken()
        print("Calling led on")
        table_print(t)
        print("---")
        left = t:led(left)
        --print("endloop")
    end
    return left
end
