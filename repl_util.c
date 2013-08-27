#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <histedit.h>

#include "terra.h"


///////////////////////////////////////

static EditLine *el_state;
static History  *el_hist;

static lua_State *lua_state;


static void die(lua_State * L) {
    fprintf(stderr, "%s\n",luaL_checkstring(L,-1));
    exit(1);
}

///

static const char *readline()
{
    int count;
    return el_gets(el_state, &count);
}

static int readline_lua(lua_State *L)
{
    assert(lua_gettop(L) == 0); // no arguments

    const char *line = readline();
    lua_pushstring(L, line);
    return 1;
}

static void init_terra()
{
    lua_State *L = luaL_newstate();
    assert(L);
    luaL_openlibs(L);
    if (terra_init(L))
        die(L);

    // set up the line reading function
    lua_pushcfunction(L, readline_lua);
    lua_setfield(L, LUA_GLOBALSINDEX, "aether_readline");

    assert(0 == luaL_dofile(L, "tokens.lua"));

    lua_state = L;
}

///////////////////////////////////////

static int pending_prompt;

static void push_prompt()
{
    pending_prompt = 1;
}

static void pop_prompt()
{
    pending_prompt = 0;
}

static char *prompt(EditLine *el)
{
    return (pending_prompt ? "… " : "» ");
}

static void push_history(const char *line)
{
    if (strlen(line)) {
        HistEvent ev;
        history(el_hist, &ev, H_ENTER, line);
    }
}

static void teardown()
{
    printf("\nCome back soon!\n");

    history_end(el_hist);
    el_end(el_state);

    lua_close(lua_state);
    terra_llvmshutdown();
}

// http://www.cs.utah.edu/~bigler/code/libedit.html
void repl_init()
{
    init_terra();

    el_state = el_init("ai", stdin, stdout, stderr);
    if (!el_state) {
        fprintf(stderr, "repl_init error\n");
        exit(1);
    }

    el_set(el_state, EL_PROMPT, prompt);
    el_set(el_state, EL_EDITOR, "emacs");

    el_hist = history_init();

    HistEvent ev;
    history(el_hist, &ev, H_SETSIZE, 100);

    /* This sets up the call back functions for history functionality */
    el_set(el_state, EL_HIST, history, el_hist);

    atexit(teardown);
}

void print_welcome()
{
    printf("Welcome to Aether!\n");
}

int repl_doexpr()
{
    lua_State *L = lua_state;

    assert(lua_gettop(L) == 0); // sanity check

    const char *line = readline();
    if (!line)
        return -1;

    push_history(line);
    push_prompt();

    lua_getfield(L, LUA_GLOBALSINDEX, "doexpr");
    lua_pushstring(L, line);
    lua_call(L, 1, 1);

    pop_prompt();

    assert(lua_gettop(L) == 1);
    assert(lua_isnumber(L, 1));

    int result = lua_tonumber(L, 1);
    lua_pop(L, 1);

    return result;
}
