---------------------------
-- *** LineTokenizer *** --
---------------------------


-- import global dependencies
local coroutine = _G.coroutine
local error = _G.error
local ipairs = _G.ipairs
--local print = _G.print
local pcall = _G.pcall
local require = _G.require
local aether_readline = _G.aether_readline

-- Prevent modifications to global environment
local package_env = {}
setfenv(1, package_env)


Tokens = require("tokens")

-- This will be turned into a coroutine continuosly yielding a stream of
-- tokens. Use for line-based input.
--
-- Dependendcies:
--  * "tokenize" function
--  * external function "aether_readline".
function make_token_fn(line)
    return function(async)
        while true do
            --print("tokenizing line")
            local toks = Tokens.tokenize(line)
            --print("did end tokenizing line")
            for _, t in ipairs(toks) do
                async = coroutine.yield(t)
            end
            --print("no toks")
            --table_print(opt)

            while async do
                async = coroutine.yield(nil)
            end

            line = aether_readline()
            if line == nil then
                -- EOF
                return
            end
            --print("Did read line "..line)
        end
    end
end

function make_token_coro(line)
    return coroutine.wrap(make_token_fn(line))
end

-- Returns two functions: one for synchronous token fetching and the other one
-- for asynchronous.
function make_token_api(line)
    local get_token_coro = make_token_coro(line)
    local get_token_sync = function()
        return get_token_coro(false)
    end
    local get_token_async = function()
        return get_token_coro(true)
    end
    return get_token_sync, get_token_async, get_token_coro
end

function new(line)
    local lookbehind_token
    local current_token
    local next_token

    local get_token_sync, get_token_async, _token_coro_fn = make_token_api(line)

    local tokenizer = {}

    -- useful to clean up the state in case of errors
    function tokenizer.reset()
        lookbehind_token = nil
        current_token = nil
        next_token = nil
    end

    -- returns the next token if there are any left in the current batch
    -- (usually a single line)
    function tokenizer.peekToken()
        if next_token then
            return next_token
        end
        next_token = get_token_async()
        --if next_token then
            --print("did peek token "..next_token.value)
        --else
            --print("did peek no token")
        --end
        return next_token
    end

    -- forcibly requests the next token
    function tokenizer.pullToken()
        lookbehind_token = current_token
        if next_token then
            current_token = next_token
            next_token = nil
        else
            current_token = get_token_sync()
        end
        return current_token
    end

    function tokenizer.pushToken()
        next_token = current_token
        current_token = lookbehind_token
        lookbehind_token = nil
    end

    function tokenizer.skip(typ)
        if not typ then
            if tokenizer.peekToken() then
                error("Expected end of line. Got `"..Tokens.formatoken(tokenizer.peekToken()).."`")
            end
            next_token = nil
            return
        end

        local tok = tokenizer.pullToken()
        if not tok then
            error("Expected "..typ) --end of line") -- FIXME  (1 + 2 + \n 3
        elseif not Tokens.tokensEqual(tok, typ) then
            --table_print(node)
            error("Unexpected token `"..Tokens.formatoken(tok).."`. Expected `"..Tokens.formatoken(typ).."`")
        end
    end

    function tokenizer.atEOF()
        local status, errorstr = pcall(_token_coro_fn)
        return status == false and errorstr == "cannot resume dead coroutine"
    end

    return tokenizer
end

return {
    new = new,
    --tokenize = Tokens.tokenize,
    --printoken = Tokens.printoken,
    --printokens = Tokens.printokens,
    makeToken = Tokens.makeToken
}
