require("tokens")

function assertEq(given, expected)
    if given ~= expected then
        error("Assertion failed. Expected `"..given.."` to be equal to `"..expected.."`")
    end
end

n = parseNumber("123")
assertEq(n.value, "123")
assertEq(n.type, "int")

n = parseNumber("123.")
assertEq(n.value, "123.")
assertEq(n.type, "float")

n = parseNumber("123.45")
assertEq(n.value, "123.45")
assertEq(n.type, "float")

n = parseNumber("123.45")
assertEq(n.value, "123.45")
assertEq(n.type, "float")

n = parseNumber("123e10")
assertEq(n.value, "123e10")
assertEq(n.type, "float")

n = parseNumber("123E+10")
assertEq(n.value, "123e+10")
assertEq(n.type, "float")

n = parseNumber("123E-10")
assertEq(n.value, "123e-10")
assertEq(n.type, "float")

-- FIXME
n = parseNumber("123.f")
assertEq(n.value, "123.")
assertEq(n.type, "float")

n = parseNumber("123. f")
assertEq(n.value, "123.")
assertEq(n.type, "float")

-- FIXME
n = parseNumber("123uint32")
assertEq(n.value, "123")
assertEq(n.type, "int")

n = parseNumber("123.45E-10")
assertEq(n.value, "123.45e-10")
assertEq(n.type, "float")

n = parseNumber("123 .45E-10")
assertEq(n.value, "123")
assertEq(n.type, "int")

n = parseNumber("123 abc")
assertEq(n.value, "123")
assertEq(n.type, "int")

-- FIXME
n = parseNumber("123_abc_d")
assertEq(n.value, "123")
assertEq(n.type, "int")

n = parseNumber("123 4 abc_d")
assertEq(n.value, "123")
assertEq(n.type, "int")

n = parseNumber("123 4.f abc_d")
assertEq(n.value, "123")
assertEq(n.type, "int")

-- FIXME
n = parseNumber("4.f abc_d")
assertEq(n.value, "4.")
assertEq(n.type, "float")

-- FIXME
n = parseNumber("4.f 5a")
assertEq(n.value, "4.")
assertEq(n.type, "float")

status, err = pcall(parseNumber, "123.45E")
assert(not status)
assertEq(err, "Malformed number")

function tokensEqual(t1, t2)
    if t1.type ~= t2.type then return false end

    if t1.type == "identifier" then
        return t1.name == t2.name
    elseif t1.type == "operator" then
        return t1.token == t2.token
    else
        return t1.value == t2.value
    end
end


toks = tokenize("4.f 5a abc 1_a1 _1 A_4_5 ab_1 +-+^*/++<===(){:::}")
ref_toks = {
    makeLiteralFloat("4."),
    makeIdentifier("f"),  -- FIXME
    makeLiteralInt("5"),
    makeIdentifier("a"),  -- FIXME
    makeIdentifier("abc"),
    makeLiteralInt("1"),
    makeIdentifier("_a1"),  -- FIXME
    makeIdentifier("_1"),
    makeIdentifier("A_4_5"),
    makeIdentifier("ab_1"),
    makeOperator("+"),
    makeOperator("-"),
    makeOperator("+"),
    makeOperator("^"),
    makeOperator("*"),
    makeOperator("/"),
    makeOperator("++"),
    makeOperator("<="),
    makeOperator("=="),
    makeTerminal("("),
    makeTerminal(")"),
    makeTerminal("{"),
    makeTerminal("::"),
    makeTerminal(":"),
    makeTerminal("}"),
}

printokens(toks)
assert(#toks == #ref_toks)
for i, t in ipairs(ref_toks) do
    assert(tokensEqual(t, toks[i]), "Failed to compare toks at index "..i.." ("..t.value.." != "..toks[i].value..")")
end
