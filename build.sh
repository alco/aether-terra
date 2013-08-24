clang -g -L ~/Documents/git/terra/build -ledit -lluajit -lterra -pagezero_size 10000 -image_base 100000000 -I ~/Documents/git/terra/src repl.c repl_util.c -o ai
