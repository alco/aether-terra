#include <stdlib.h>

#include <histedit.h>


char *prompt(EditLine *el)
{
    return "» "; // : "… ");
}

static EditLine *el_state;

void teardown()
{
    printf("\nCome back soon!\n");
    el_end(el_state);
}

void repl_init()
{
    el_state = el_init("ai", stdin, stdout, stderr);
    if (!el_state) {
        fprintf(stderr, "repl_init error\n");
        exit(1);
    }

    el_set(el_state, EL_PROMPT, prompt);
    el_set(el_state, EL_EDITOR, "emacs");

    atexit(teardown);
}

void print_welcome()
{
    printf("Welcome to Aether!\n");
}

const char *readline()
{
    int count;
    return el_gets(el_state, &count);
}
