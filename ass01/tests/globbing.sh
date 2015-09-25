#!/bin/sh

# call(sorted(glob.glob("./[*][[][]][?][.]*?")) + sorted(glob.glob("[*][[][]][?][.]*?")))
./\*\[\]\?[.]*? '*[]?'[.]*?

# print " ".join(["a"] + sorted(glob.glob("./[*][[][]][?][.]*?")) + ["b", "c"] + sorted(glob.glob("[*][[][]][?][.]*?")) + ["d"])
echo a ./\*\[\]\?[.]*? b c '*[]?'[.]*? d

# a = "./*[?][.]*?"
# b = "./\\*\\[\\?\\][.]*?"
# c = "a"
# print " ".join(["a"] + sorted(glob.glob(a)) + ["b", "c"] + sorted(glob.glob(b)) + ["d", c, "e"])
# call(["a"] + sorted(glob.glob(a)) + ["b", "c"] + sorted(glob.glob(b)) + ["d", c, "e"])
a=./\*\[\?\][.]*?
b='./\*\[\?\][.]*?'
c=a
echo a $a b c $b d $c e
a $a b c $b d $c e

# os.chdir(sorted(glob.glob("examples/*"))[0])
cd examples/*
