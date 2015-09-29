#!/bin/sh

# (Modified from posh's test suite)
# print "|&;<>()$`\\\"' \tThis a continuation\\\n#of\n the", "echo", "line" # and a multi-line comment \
# subprocess.call(["or", "not?"])
echo \|\&\;\<\>\(\)\$\`\\\"\'\ \	\
'This a c'on''''''tinuatio'n\
#of
 t'he echo li\ne # and a multi-line comment \
or not\?
