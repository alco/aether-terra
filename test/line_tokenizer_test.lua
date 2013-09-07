function assertEq(given, expected)
    if given ~= expected then
        error("Assertion failed. Expected `"..given.."` to be equal to `"..expected.."`")
    end
end

function assertNil(given)
    if given ~= nil then
        error("Assertion failed. Expected `"..given.."` to be nil")
    end
end

---

LineTokenizer = require("tokenizer")
tt = LineTokenizer.new("initial 1st line")

fixture_tokens = {
    { type = "ident", value = "initial" },
    { type = "ident", value = "initial" },
    { type = "int", value = "1" },
    { type = "ident", value = "st" },
    { type = "ident", value = "line" }
}

tok = tt.peekToken()
for i, t in ipairs(fixture_tokens) do
    assertEq(tok.type, t.type)
    assertEq(tok.value, t.value)

    if i < #fixture_tokens then
        tok = tt.pullToken()
    end
end
assertNil(tt.peekToken())

tt.pushToken()
tok = tt.pullToken()
assertEq(tok.type, "ident")
assertEq(tok.value, "line")

-- pulling tokens from the next line (defined in line_tokenizer_test.c)
tok = tt.pullToken()
assertEq(tok.type, "operator")
assertEq(tok.value, "-")

fixture_tokens = {
    { type = "ident", value = "x" },
    { type = "operator", value = "**" },
    { type = "term", value = "(" },
    { type = "int", value = "4" },
    { type = "operator", value = "-" },
    { type = "float", value = "2." },
    { type = "term", value = ")" }
}

for i = 1, #fixture_tokens do
    tok = tt.peekToken()
    assertEq(tok.type, fixture_tokens[i].type)
    assertEq(tok.value, fixture_tokens[i].value)

    tt.pullToken() -- FIXME: replace by skip?
end
assertNil(tt.peekToken())

-- pull another fixture line
tok = tt.pullToken()
-- FIXME: test expect()
assertEq(tok.type, "operator")
assertEq(tok.value, "+")

tok = tt.peekToken()
assertEq(tok.type, "int")
assertEq(tok.value, "1")

-- FIXME: test skip()
tt.pullToken()

assertNil(tt.pullToken())

-- FIXME: test newline
-- FIXME: test lookbehind
