#!/bin/sh

parent_dir=$(cd ..; pwd)
export LUA_PATH="$parent_dir/?.lua;;"

./line_tokenizer_test          \
&& lua file_tokenizer_test.lua \
&& lua parser_test.lua         \
&& lua file_parser_test.lua    \
#&& lua typecheck_test.lua      \
