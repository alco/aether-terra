---------------------------
-- *** Tokenizer *** --
---------------------------


-- import global dependencies
local coroutine = _G.coroutine
local error = _G.error
local io = _G.io
local ipairs = _G.ipairs
--local print = _G.print
local pcall = _G.pcall
local require = _G.require
local type = _G.type

-- Prevent modifications to global environment
local package_env = {}
setfenv(1, package_env)


Tokens = require("tokens")

-- This will be turned into a coroutine continuosly yielding a stream of
-- tokens.
--
-- Dependendcies:
--  * Tokens.tokenize()
function make_token_fn(line, readline_fn)
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

            line = readline_fn()
            if line == nil then
                -- EOF
                return
            end
            --print("Did read line "..line)
        end
    end
end

-- Returns two functions: one for synchronous token fetching and the other one
-- for asynchronous. The third return value is the underlying coroutine function.
function make_token_api(make_tok_fn)
    local get_token_coro = coroutine.wrap(make_tok_fn)
    local get_token_sync = function()
        return get_token_coro(false)
    end
    local get_token_async = function()
        return get_token_coro(true)
    end
    return get_token_sync, get_token_async, get_token_coro
end

function new(opts)
    local first_line, readline_fn
    if opts.line then
        -- line tokenizer
        if not opts.readline_fn then
            error("Expected 'readline_fn' option with 'line'")
        end
        first_line, readline_fn = opts.line, opts.readline_fn
    elseif opts.file then
        -- file tokenizer
        local lines = io.lines(opts.file)
        first_line, readline_fn = lines(), function()
            return lines()
        end
    else
        error("One of 'line' or 'file' options expected")
    end

    local get_token_sync, get_token_async, _token_coro_fn
            = make_token_api(make_token_fn(first_line, readline_fn))

    local lookbehind_token, current_token, next_token

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
            if type(typ) == "string" then
                error("Expected "..typ) --end of line") -- FIXME  (1 + 2 + \n 3
            else
                error("Expected "..Tokens.formatoken(typ)) --end of line") -- FIXME  (1 + 2 + \n 3
            end
        elseif type(typ) == "string" then
            if tok.value ~= typ then
                error("Unexpected token `"..Tokens.formatoken(tok).."`. Expected `"..typ.."`")
            end
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
