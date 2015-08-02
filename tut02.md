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

 - Regex needs to be quoted to stop the shell parsing the `|` as a pipe
 - POSIX regex (that `grep` uses by default) requires the `|` operator to be `\|`
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

## 7.
For each of the scenarios below
 - describe the strings being matched using an English sentence
 - give a POSIX regular expression to match this class of strings

In the examples, the expected matches are highlighted in bold.

### encrypted password fields (including the surrounding colons) in a Unix password file entry
e.g.

<pre>root**:ZHolHAHZw8As2:**0:0:root:/root:/bin/bash
jas**:nJz3ru5a/44Ko:**100:100:John Shepherd:/home/jas:/bin/bash</pre>

- Second field of colon separated data, including the surrounding colons

```
/^[^:]*(:[^:]*:)/gm
```

### positive real numbers at the start of a line
(using normal fixed-point notation for reals, *not* the kind of scientific notation you find in programming languages)

e.g.
<pre>**3.141** value of Pi
**90.57** maximum hits/sec
half of the time, life is silly
**0.05**% is the legal limit
**42** - the meaning of life
this 1.333 is not at the start</pre>

- (One or more digits, optionally followed by a decimal point and possibly more digits) or (zero or more digits, followed by a decimal point and one or more digits) at the start of the line

```
/^(\d+(?:\.\d*)?|\d*\.\d+)/gm`
```

### Names as represented in the previous question (including the special coding for persons with a single name)
- Fifth field of colon separated data

```
/^(?:[^:]*:){4}([^:]*):/gm
```

### Names as above, but without the trailing spaces (difficult)
*Hint:* what are given names composed of, and how many of these things can there be?

See above

## 8. Consider the following columnated (space-delimited) data file containing marks information for a single subject
```
2111321 37 FL
2166258 67 CR
2168678 84 DN
2186565 77 DN
2190546 78 DN
2210109 50 PS
2223455 95 HD
2266365 55 PS
...
```

Assume that the student number occurs at the beginning of the line, that the file is sorted on student number, and that nobody scores 100.

### a. Give calls to the sort filter to display the data:
#### i. in order on student number
```
sort -nk1
```

#### ii. in ascending order on mark
```
sort -nk2
```

#### iii. in descending order on mark
```
sort -nrk2
```

### b. Write calls to the grep filter to select details of:
#### i. students who failed
```
grep FL
```

#### iii. students who scored above 90
```
grep -E '^[[:digit:]]+ 9[[:digit:]]'
```

#### iii. students with even student numbers
```
grep -E '^[[:digit:]]+[02468] '
```

### c. Write a pipeline to print:
#### i. the details for the top 10 students (ordered by mark)
```
sort -nrk2 | head -n10
```

#### ii. the details for the bottom 5 students (ordered by mark)
```
sort -nrk2 | tail -n5
```

### d. Assuming that the command cut -d' ' -f 3 can extract just the grades (PS, etc.), write a pipeline to show how many people achieved each grade (i.e. the grade distribution)
E.g. for the above data:
```
    1 CR
    3 DN
    1 FL
    1 HD
    2 PS
```

```
cut -d' ' -f3 | sort | uniq -c
```

## 9. Consider the following text file containing details of tute/lab enrolments:
```
    2134389|Wang, Duved Seo Ken         |fri15-spoons|
    2139656|Undirwaad, Giaffriy Jumis   |tue13-kazoo|
    2154877|Ng, Hinry                   |tue17-kazoo|
    2174328|Zhung, Yung                 |thu17-spoons|
    2234136|Hso, Men-Tsun               |tue09-harp|
    2254148|Khorme, Saneu               |tue09-harp|
    2329667|Mahsin, Zumel               |tue17-kazoo|
    2334348|Trun, Toyin Hong Recky      |mon11-leaf|
    2336212|Sopuvunechyunant, Sopuchue  |mon11-leaf|
    2344749|Chung, Wue Sun              |fri09-harp|
    ...
```

Assuming that the file is called `enrolments`, write pipelines to answer each of the following queries:

### a. Which tute is Hinry Ng enrolled in?
```
awk -F'|' '$2 == "Ng, Hinry                   " {print $3}' enrolments
```

### b. How many different tutorials are there?
```
cut -d'|' -f3 enrolments | sort -u | wc -l
```

### c. What is the number of students in each tute?
```
cut -d'|' -f3 enrolments | sort | uniq -c
```

### d. Are any students enrolled in multiple tutes?
```
sort -u enrolments | cut -d'|' -f1,2 | sort | uniq -d
```
