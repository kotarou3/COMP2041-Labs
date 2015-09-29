#!/bin/sh

# subprocess.call(sorted(glob.glob("./[*][[][]][?][.]*?")) + sorted(glob.glob("[*][[][]][?][.]*?")) + ["[a"] + sorted(glob.glob("]*")))
./\*\[\]\?[.]*? '*[]?'[.]*? [a ]*

# print " ".join(["a"] + sorted(glob.glob("./[*][[][]][?][.]*?")) + ["b", "c"] + sorted(glob.glob("[*][[][]][?][.]*?")) + ["[a"] + sorted(glob.glob("]*")) + ["d"])
echo a ./\*\[\]\?[.]*? b c '*[]?'[.]*? [a ]* d

# FIXME: Fails
# print " ".join(sorted(glob.glob("[[]a[[]*")))
echo [a\[*

# a = "./*[?][.]*?"
# b = "./\\*\\[\\?\\][.]*?"
# c = "[a"
# print " ".join(["a"] + sorted(glob.glob(a)) + ["b", "c"] + sorted(glob.glob(b)) + ["d", c, "e"])
# subprocess.call(["a"] + sorted(glob.glob(a)) + ["b", "c"] + sorted(glob.glob(b)) + ["d", c, "e"])
a=./\*\[\?\][.]*?
b='./\*\[\?\][.]*?'
c=[a
echo a $a b c $b d $c e
a $a b c $b d $c e

# os.chdir(sorted(glob.glob("examples/*"))[0])
cd examples/*
