#include <stdio.h>

#include "repl.h"

int doloop()
{
    while (1) {
        const char *line = readline();
        if (!line)
            break;
        if (*line != '\n')
            printf("%s", line);
    }
    return 0;
}

int main(int argc, const char *argv[])
{
    repl_init();
    print_welcome();
    return doloop();
}
