#include <stdio.h>

#include "repl.h"


int doloop()
{
    while (1) {
        /*printf("Calling repl_doexpr()\n");*/
        int result = repl_doexpr();
        if (result == -1)
            break;

        /*if (result > 0)*/
            /*printf("result = %d\n", result);*/

    }
    return 0;
}

int main(int argc, const char *argv[])
{
    repl_init();
    print_welcome();
    return doloop();
}
