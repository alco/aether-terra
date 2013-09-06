--_token = nil
_next_parse_node = nil

--function startParser(tokens)
    --_token = nil
    --nextToken()
--end

function resetParser()
    --print("reset parser")
    _next_parse_node = nil
end

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
    int = {
        id = "int",
        valtype = "int",
        lbp = 0,
        nud = function(self)
            return self
        end,
        pretty_print = function(self)
            return self.value
        end
    },

    float = {
        id = "float",
        valtype = "float",
        lbp = 0,
        nud = function(self)
            return self
        end,
        pretty_print = function(self)
            return self.value
        end
    },

    ident = {
        id = "ident",
        lbp = 0,
        nud = function(self)
            return self
        end,
        pretty_print = function(self)
            return self.value
        end
    },

    string = {
        id = "string",
        valtype = "string",
        lbp = 0,
        nud = function(self)
            return self
        end
    },

    nl = { id = "newline", lbp = 0 },

    [";"] = { id = ";", lbp = 0 }
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
    tab.pretty_print = function(self)
        return "("..self.id.." "..self.first:pretty_print()..")"
    end
end

local function infix(op, precedence)
    local tab = symbol(op, precedence)
    tab.led = function(self, other)
        self.first = other
        self.second = expression(precedence)
        return self
    end
    tab.pretty_print = function(self)
        return "("..self.id.." "..self.first:pretty_print().." "..self.second:pretty_print()..")"
    end
end

local function infix_r(op, precedence)
    local tab = symbol(op, precedence)
    tab.led = function(self, other)
        self.first = other
        self.second = expression(precedence-1)
        return self
    end
    tab.pretty_print = function(self)
        return "("..self.id.." "..self.first:pretty_print().." "..self.second:pretty_print()..")"
    end
end

local function make_square(op, precedence)
    local tab = symbol(op, precedence)
    tab.led = function(self, other)
        self.id = "**"
        self.first = other
        self.second = { type="int", value="2", pretty_print = function(self) return "2" end }
        return self
    end
    tab.pretty_print = function(self)
        return "("..self.id.." "..self.first:pretty_print().." "..self.second:pretty_print()..")"
    end
end

function pretty_print(sym)
    --table_print(sym)
    if sym.first and sym.second then
        -- binary op
        return "("..sym.id.." "..pretty_print(sym.first).." ".. pretty_print(sym.second)..")"
    elseif sym.first then
        -- unary op
        return "("..sym.id.." "..pretty_print(sym.first)..")"
    elseif sym.second then
        -- slice
        return "("..sym.id.." _ "..pretty_print(sym.second)..")"
    elseif sym.exprs then
        local str = "("..sym.id
        for _, e in ipairs(sym.exprs) do
            str = str .. " " .. pretty_print(e)
        end
        return str .. ")"
    elseif sym.args then
        local str = "("..sym.id
        if sym.name then
            str = str .. " " .. pretty_print(sym.name)
        end
        for _, x in ipairs(sym.args) do
            str = str .. " " .. pretty_print(x)
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
        return sym:pretty_print()
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
    elseif tok.type == "ident" then
        if symbol_table[tok.value] then
            sym = make_symbol(tok.value)
        else
            sym = make_symbol(tok.type)
            sym.value = tok.value
        end
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

function parse_slice_expr()
    local node = nextParseNode()
    if node.id == "]" then
        return nil
    end

    if node.id == ":" then
        local fst = parse_slice_right()
        if fst then
            node.second = fst
        else
            node.value = ":"
        end
        return node
    end

    putBackNode(node)
    local left = expression()

    node = nextParseNode()
    if node.id == ":" then
        node.first = left
        local snd = parse_slice_right()
        if snd then
            node.second = snd
        end
        return node
    else
        putBackNode(node)
        skip("]")
        return left
    end
end

function parse_slice_right()
    local next_node = nextParseNode()
    if next_node.id == "]" then
        return nil
    end
    putBackNode(next_node)
    local expr = expression()
    skip("]")
    return expr
end

function advance(typ)
    local node = nextParseNode()
    if node.id ~= typ then
        error("Expected "..typ..". Got "..node.id)
    end
    return node
end


------------------------------

-- TODO: think about whitespace issues
-- funcall(123+3 -1 [1 2 3] a [5])
-- funcall((123 + 3) -1 [1 2 3] a [5])
-- funcall(❨123 + 3❩ -1 [1 2 3] a [5])
-- funcall(123 + 3, -1, [1 2 3], a, [5])
-- funcall(a: 123 + 3 b: -1 c: [1 2 3] d: a e: [5])
--
-- [:a 1 :b 2 :c 3]
-- [a: 1, b: 2, c: 3]
--
-- [a [b c] d[4]]

infix("=", 1)

-- Comparisons
infix("==", 9)
infix("≠",  9)
infix("<",  9)
infix("≤",  9)
infix(">",  9)
infix("≥",  9)

-- Arithmetic
infix("+", 10)
infix("-", 10)
infix("*", 20)
infix("/", 20)
infix("•", 20)

-- Key-value pair
infix(":", 25)

-- Unary ops
--prefix("+", 40)
prefix("-", 30)

infix_r("↑",  40)  -- exponentiation
infix_r("**", 40)  -- exponentiation
make_square("²", 40)   -- exponentiation

-- Access
infix(".", 50)

-- TODO: tuples
-- ⟨ ⟩

symbol(")")

-- Grouping expressions
symbol("(").nud = function(self)
    -- self is discarded

    local node = nextParseNode()
    if node.id == ")" then
        return {} -- should be empty tuple or error instead?
    end
    putBackNode(node)

    local exprs = {expression()}
    --print("Got expr")
    --print(pretty_print(exprs[1]))

    while true do
        local at_least_one_semicolon = false
::continue::
        local node = nextParseNode()
        if node.id == ";" then
            at_least_one_semicolon = true
            goto continue
        elseif node.id == ")" then
            break
        end

        if not at_least_one_semicolon then
            error("semicolon expected")
        end

        putBackNode(node)
        local expr = expression()
        table.insert(exprs, expr)

        --print("Got expr")
        --print(pretty_print(expr))
    end
    return {
        type="block", id="block", exprs=exprs,
        pretty_print = function(self)
            local argstr = ""
            for _, expr in ipairs(self.exprs) do
                argstr = argstr .. " " .. expr:pretty_print()
            end
            return "(block"..argstr..")"
        end
    }
end
symbol(" (").nud = symbol("(").nud

-- Funcalls
symbol("(", 1).led = function(self, left)
    self.id = "funcall"
    self.name = left
    self.args = parse_expr_list_until(")")
    return self
end

symbol("(").pretty_print = function(self)
    local argstr = ""
    for _, expr in ipairs(self.args) do
        argstr = argstr .. " " .. expr:pretty_print()
    end
    return "("..self.name:pretty_print()..argstr..")"
end

symbol("[", 101)
symbol("]")

-- Array literal
symbol("[").nud = function(self)
    self.id = "array"
    self.args = parse_expr_list_until("]")
    return self
end

-- Array subscript
symbol("[").led = function(self, left)
    self.id = "subscript"
    self.first = left
    local slice = parse_slice_expr()
    if slice then
        self.second = slice
    end
    return self
end


symbol("{", 101)
symbol("}")
--symbol(":")

-- Dict/map
symbol("{").nud = function(self)
    self.id = "map"
    self.args = parse_expr_list_until("}")
    return self
end

-- Constructor
symbol("{").led = function(self, left)
    self.id = "cons"
    self.name = left
    self.args = parse_expr_list_until("}")
    return self
end

-- Assignment
-- FIXME: turn it into statement
infix("=")

-- Variable declaration
symbol("var").nud = function(self)
    self.type = "var"
    local expr = expression()
    if expr.id == "ident" then
        self.first = expr
    elseif expr.id == "=" then
        self.first = expr.first
        self.second = expr.second
    else
        error("Bad variable definition")
    end
    return self
end

-- Function literal
symbol("fn").nud = function(self)
    self.type = "fn"
    local node = nextParseNode()
    if node.id == "(" then
        -- function literal
        self.head = parse_expr_list_until(")")
        self.body = expression()
    else
        -- function definition
        putBackNode(node)

        local expr = expression()
        --print(pretty_print(expr))
        if expr.id ~= "funcall" then
            error("Expected a function declaration")
        end
        self.head = expr
        --if peekParseNode() and peekParseNode().id == "::" then
            --self.sig = expression()
        --end
        self.body = expression()
    end
    return self
end

symbol("fn").pretty_print = function(self)
    local head
    if self.head.id then
        head = self.head:pretty_print()
    else
        head = "("
        for _, arg in ipairs(self.head) do
            head = head .. arg:pretty_print() .. " "
        end
        head = head .. ")"
    end
    return "(fn "..head.." "..self.body:pretty_print()..")"
end

symbol("->")
symbol("::").nud = function(self)
    self.first = parse_type()
    table_print(self.first)
    return self
end

function parse_type()
    -- a type is one of
    --  * primitive type
    --  * type -> type
    local typexpr = parse_primitive_type()
    if peekParseNode() and peekParseNode().id == "->" then
        skip("->")
        return { type = "fn", spec = { typexpr, parse_type() } }
    end
    return typexpr
end

function parse_primitive_type()
    -- A primitive type is one of
    --  * identifier
    --  * type variable
    --  * []type
    --  * [number]type
    --  * {type: type}   // map
    --  * parenthesised list of types (tuple, function arglist)
    local node = nextParseNode()
    if node.id == "ident" then
        if is_greek_letter(node.value) then
            return { type = "typevar", spec = node.value }
        else
            return { type = "concrete type", spec = node.value }
        end
    elseif node.id == "[" then
        return parse_array_type()
    elseif node.id == "{" then
        return parse_map_type()
    elseif node.id == " (" then
        return parse_list_of_types()
    elseif node.id == "(" then
        return parse_list_of_types()
    end
    error("Bad type spec")
end

function is_greek_letter(str)
    return false
end

function parse_array_type()
    -- []int     // dynamic array of ints / slice
    -- [5]int    // static array of ints / vector
    -- [4,5]int  // two-dimensional array of ints
    -- [..2]int  // two-dimensional slice
    -- [..3]int  // three-dimensional slice
    -- [4][5]int // array of arrays
    local node = nextParseNode()
    assert(node.id == "]")
    return { type = "array", size = "dynamic", elemtype = parse_type() }
end

function parse_map_type()
    -- {key: value}                // map
    -- {key1: {key2: value}}       // map of map
    -- {key1: [5]value}            // map of arrays
    local keytype = parse_type()
    skip(":")
    local valuetype = parse_type()
    return { type = "map", keytype = keytype, valuetype = valuetype }
end

function parse_list_of_types()
    local node = nextParseNode()
    local args = {}
    while node.id ~= ")" do
        putBackNode(node)
        table.insert(args, parse_type())
        node = nextParseNode()
    end
    return { type = "arglist", args = args }
end

--table_print(symbol_table)
