#!/bin/sh

parent_dir=$(cd ..; pwd)
export LUA_PATH="$parent_dir/?.t;$parent_dir/?.lua;;"

./line_tokenizer_test          \
&& lua file_tokenizer_test.lua \
&& terra parser_test.lua       \
&& terra file_parser_test.lua  \
&& terra typecheck_test.lua    \
&& terra codegen_test.t        \
