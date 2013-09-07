#include <assert.h>
#include <stdlib.h>
#include <stdio.h>

#include "terra.h"


static void die(lua_State * L) {
    fprintf(stderr, "%s\n", luaL_checkstring(L, -1));
    exit(1);
}

///

static int readline_lua(lua_State *L)
{
    // Fake a number of additional lines, then send EOF.
    static const char *fixtures[] = {
        "-x**(4-2.)",
        "+1",
        NULL
    };
    static int counter;

    lua_pushstring(L, fixtures[counter++]);
    return 1;
}

int main()
{
    lua_State *L = luaL_newstate();
    assert(L);
    luaL_openlibs(L);

    // set up the line reading function
    lua_pushcfunction(L, readline_lua);
    lua_setfield(L, LUA_GLOBALSINDEX, "aether_readline");

    if (luaL_dofile(L, "line_tokenizer_test.lua")) {
        die(L);
    }

    return 0;
}
