all: ai

DEBUG_CFLAGS = -g
TERRA_LFLAGS = -L ~/Documents/git/terra/build -lluajit -lterra -pagezero_size 10000 -image_base 100000000
TERRA_CFLAGS = -I ~/Documents/git/terra/src
	
ai: repl.c repl_util.c
	clang $(DEBUG_CFLAGS) -ledit $(TERRA_LFLAGS) $(TERRA_CFLAGS) -o ai repl.c repl_util.c

.PHONY: test

test:
	clang $(TERRA_LFLAGS) $(TERRA_CFLAGS) -o test/line_tokenizer_test test/line_tokenizer_test.c
