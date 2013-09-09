#!/bin/sh

./line_tokenizer_test &&
lua file_tokenizer_test.lua &&
lua parser_test.lua &&
lua file_parser_test.lua
