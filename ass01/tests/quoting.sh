#!/bin/sh

# (Modified from posh's test suite)

# print "|&;<>()$`\\\"' \tThis a continuation\\\n#of\n the", "echo line" # and a multi-line comment \
# subprocess.call(["or", "not?"])
echo \|\&\;\<\>\(\)\$\`\\\"\'\ \	\
'This a c'on''''''tin""""uatio'n\
#of
 t'he ec"ho\
 "li\ne # and a multi-line comment \
or not\?

FULLVARIABLE="Two words"

# print "One $EMPTYVARIABLE"
# print "$(echo cmdsubst $FULLVARIABLE)"
# print "`echo backquot $FULLVARIABLE`"
# print "One {0}".format(EMPTYVARIABLE)
# print " ".join("cmdsubst", FULLVARIABLE)
# print " ".join("backquot", FULLVARIABLE)
echo 'One $EMPTYVARIABLE'
echo '$(echo cmdsubst $FULLVARIABLE)'
echo '`echo backquot $FULLVARIABLE`'
echo "One $EMPTYVARIABLE"
echo "$(echo cmdsubst $FULLVARIABLE)"
echo "`echo backquot $FULLVARIABLE`"
