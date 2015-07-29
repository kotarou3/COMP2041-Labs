# Filters and Regexps

## 1.
### a. Write a regexp to match C preprocessor commands in a C program.
```
/
    ^
    [ \t\x0b\f]*     # Ignore leading whitespace
    (
        \#.*?        # First line of directive...
        (?:\\\n.*?)* # ...and any continued lines
    )
    $
/gmx
```

### b. Write a regexp to match all the lines in a C program except preprocessor commands
```
/
    ^
    (?:
        [ \t\x0b\f]*\#.*?(?:\\\n.*?)* # Don't capture any preprocessor directives
    |
        (.*)
    )
    $
/gmx
```

### c. Write a regexp to find line in a C program with trailing white space - one or white space at the end of line
```
/^(.*[ \t\x0b\f]+)$/gm
```

### d. Write a regexp to match the names Barry, Harry, Larry and Parry

```
/\b([bhlp]arry)\b/gi
```

### e. Write a regexp to match a string containing the word hello followed later by the word world
```
/\b(hello\b.*?\bworld)\b/gi
```

### f. Write regexp to match the word calendar and all mis-spellings with 'a' replaced 'e' or vice-versa
```
/\b(c[ae]l[ae]nd[ae]r)\b/gi
```

### g. Write regexp to match a list of positive integers spearated by commas, e.g. 2,4,8,16,32
```
/(\d(?:,\d)+)/g
```

### h. Write regexp to match a C string whose last character is newline
 - Assuming "C string" meaning "C string literal in C source code"
 - Note: The `(?:[^"\n]|\\(?:\\\\)*")` matches everything except newlines and unescaped quotes

```
/
    (?:
        # Skip preprocessor directives
        ^[ \t\x0b\f]*\#.*?(?:\\\n.*?)*$
    |
        # Don't capture but still parse any strings not ending in newlines
        "                             # String start
        (?:[^"\n]|\\(?:\\\\)*")*?     # First source line of string...
        (?:
            \\\n(?!(?:\\\n)*")        # ...and any continued lines not immediately ending the string
            (?:[^"\n]|\\(?:\\\\)*")*?
        )*
        (?<!\\)(?:\\\\)*              # Even number of backslashes (i.e., escaped backslashes)
        (?<!\\n)                      # Not ending with a newline
        (?:\\\n)*                     # And possibly more line continuations
        "                             # String end
    |(
        # Same as above, but ending in a newline, and capturing
        "
        (?:[^"\n]|\\(?:\\\\)*")*?
        (?:
            \\\n(?!(?:\\\n)*")
            (?:[^"\n]|\\(?:\\\\)*")*?
        )*
        (?<!\\)(?:\\\\)*
        \\n
        (?:\\\n)*
        "
    ))
/gmx
```

## 2.
### Give five reasons why this attempt to search a file for HTML paragraph and break tags may fail.
```sh
grep <p>|<br> /tmp/index.html
```

 - The tags might be written with different case (e.g., `<bR>`)
 - The tags might have attributes (e.g., `<p class="...">`)
 - The tags might have some trailing whitespace (e.g., `<p >`)
 - The self-closing `<br>` tag might be written XML-style (i.e., `<br/>` or `<br />`)
 - Attributes might contain the tags (e.g., `<a href="//localhost/some<p>weird<br>uri">`)
 - Comments or CDATA sections might contain the tags  (e.g., `<!-- <p>hi</p> -->`)
 - The tags might be created dynamically (e.g., via javascript)

### Give grep commands that will work.
 - Ignoring the last three points, this grep command can satisfy the rest:

```sh
grep -Ei '<(p|br)[[:space:]/>]'
```

## 3. For each of the regular expression below indicate how many different strings the pattern matches and give some example of the strings it matches. If possible these example should include the shortest string and the longest string.
### a. `Perl`
 - `Perl`

### b. `Pe*r*l`
 - `Pl`
 - `Peeeeeeeeeeeeerrrrrrrrrrrrrrrrrrrl`

### c. `Full-stop.`
 - `Full-stopy`
 - `Full-stop?`
 - `Full-stop.`

### d. `[1-9][0-9][0-9][0-9]`
 - `1000`
 - `4321`

### e. `I (love|hate) programming in (Perl|Python) and (Java|C)`
 - `I hate programming in Perl and Java`
 - `I love programming in Python and C`

## 4. This regular expression `[0-9]*.[0-9]*` is intended to match floating point numbers such as '42.5'. Is it appropriate?
 - No. `.` does not match `.` literally, but means "any character except newline", so even `12a34` would match
 - No. `*` means "zero or more times", so the current regex can even match something without numbers (e.g., `.`)
 - No. Floating point numbers means that the decimal point can denote different magnitudes, but this regex is missing an exponent to enable it to do so

## 5.
### What does the command `grep -v .` print and why?
 - Lines containing only newlines, because `-v` inverts match, and `grep .` matches any non-zero character line that isn't only a newline

### Give an equivalent grep command with no options, in other words without the -v and with a different pattern.
```sh
grep '^$'
```

## 6. Write an egrep command which will print any lines in a file `ips.txt` containing an IP addresses in the range 129.94.172.1 to 129.94.172.25
```sh
grep -E '129\.94\.172\.([1-9]|1[0-9]|2[0-5])'
```
