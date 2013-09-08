require("lunit")

Tokenizer = require("tokenizer")
tt = Tokenizer.new(g_tokenizerParams)

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
    { type = "term", value = "cparen" },
    { type = "int", value = "4" },
    { type = "operator", value = "-" },
    { type = "float", value = "2." },
    { type = "term", value = ")" }
}

for i = 1, #fixture_tokens do
    tok = tt.peekToken()
    assertEq(tok.type, fixture_tokens[i].type)
    assertEq(tok.value, fixture_tokens[i].value)

    tt.skip(Tokenizer.makeToken(tok.type, tok.value))
end
assertNil(tt.peekToken())

-- pull another fixture line
status, errorstr = pcall(tt.skip, Tokenizer.makeToken("operator", "-"))
assertEq(status, false)
assertEq(errorstr, "Unexpected token `operator : +`. Expected `operator : -`")

tok = tt.peekToken()
assertEq(tok.type, "int")
assertEq(tok.value, "1")

status, errorstr = pcall(tt.skip)
assertEq(status, false)
assertEq(errorstr, "Expected end of line. Got `int : 1`")

tt.skip(Tokenizer.makeToken("int", "1"))

assertNil(tt.pullToken())
assert(tt.atEOF())

-- FIXME: test newline
-- FIXME: test lookbehind

