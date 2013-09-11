-- Prevent modifications to global environment
local G = _G
local package_env = {}
setfenv(1, package_env)

ParserBase = G.require("new_parser")
Util = G.require("util")

function new(parent_parser)
    local parser = ParserBase.new()
    G.setmetatable(parser, { __index = parent_parser })
    --parser.tokenizer = functionparent_parser.tokenizer

    --local tokenizer = parent_parser.tokenizer

    local make_node = parser.make_node
    local make_prefix = parser.make_prefix
    local make_infix = parser.make_infix
    local make_infix_r = parser.make_infix_r

    parser.make_default_node("ident")

    make_infix("->", 10).led = function(self, left)
        local pnode = {
            id = "funcall",
            first = left, -- TODO: validate the type of left
            second = parser:expression(),
            format = function(self)
                return Util.strformat("{1} -> {2}", self.first:format(), self.second:format())
            end
        }
        return pnode
    end

    make_node(")")
    make_prefix("gparen").nud = function(self)
        local pnode = {
            id = "tuple",
            args = parser:expr_list_until(")"),
            format = function(self)
                return self.args:format()
            end
        }
        return pnode
    end

    -- some terminator nodes just to stop parsing
    make_node(",")
    make_node("=")

    --function table.make_typevar(value)
        --local typevar = make_node("ident")
        --typevar.id = "typevar"
        --typevar.value = value
        --return typevar
    --end


    local function parse_primitive_type()
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

    local function is_greek_letter(str)
        return false
    end

    local function parse_array_type()
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

    local function parse_map_type()
        -- {key: value}                // map
        -- {key1: {key2: value}}       // map of map
        -- {key1: [5]value}            // map of arrays
        local keytype = parse_type()
        skip(":")
        local valuetype = parse_type()
        return { type = "map", keytype = keytype, valuetype = valuetype }
    end

    local function parse_list_of_types()
        local node = nextParseNode()
        local args = {}
        while node.id ~= ")" do
            putBackNode(node)
            table.insert(args, parse_type())
            node = nextParseNode()
        end
        return { type = "arglist", args = args }
    end

    return parser
end

return {
    new = new
}
