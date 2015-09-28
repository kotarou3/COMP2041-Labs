#!/bin/sh

# XXX: Partially fails (extra set of brackets, but no logic errors) due to heuristics in bracket creation
# (((((((((os.access(a, os.X_OK) or os.path.exists(a) and stat.S_ISFIFO(os.stat(a).st_mode)) and not not int(a) <= int(a) or not (os.path.exists(a) and stat.S_ISBLK(os.stat(a).st_mode))) and int(a) == int(a) and len(a) > 0 and not not (os.path.exists(a) and stat.S_ISSOCK(os.stat(a).st_mode)) and (os.path.exists(a) and stat.S_ISCHR(os.stat(a).st_mode)) or int(a) < int(a) or a < a) and int(a) != int(a) and a > a or (os.path.islink(a))) and os.path.exists(a) and os.path.exists(a) and os.path.samefile(a, a) or len(a) == 0 or os.path.exists(a) and os.stat(a).st_gid == os.getegid()) and int(a) > int(a) and ((os.path.exists(a) and os.stat(a).st_mode & stat.S_ISUID)) or os.access(a, os.W_OK) or not (os.path.exists(a) and os.stat(a).st_mode & stat.S_ISVTX)) and (a == a or os.path.isdir(a)) or os.path.exists(a) and os.stat(a).st_uid == os.geteuid()) and not (os.path.exists(a) and os.stat(a).st_mode & stat.S_ISGID) or os.path.exists(a) and os.path.getsize(a) > 0) and os.path.exists(a) and len(a) > 0 or int(a) >= int(a)) and os.access(a, os.R_OK) or a != a or not (not not os.path.isfile(a)) or os.path.exists(a) and os.path.exists(a) and os.path.getmtime(a) < os.path.getmtime(a) or os.path.exists(a) and os.path.exists(a) and os.path.getmtime(a) > os.path.getmtime(a) or os.path.islink(a) or not (os.isatty(int(a)) or len(a) > 0)
test \
      \( \
            \( \
                  \( \
                        \( \
                              \( \
                                    \( \
                                          \( \
                                                \( \
                                                      \( \
                                                          -x $a \
                                                        -o \
                                                          -p $a \
                                                      \) \
                                                    -a \
                                                      ! ! $a -le $a \
                                                  -o \
                                                    ! -b $a \
                                                \) \
                                              -a \
                                                $a -eq $a \
                                              -a \
                                                $a \
                                              -a \
                                                ! ! \( -S $a \) \
                                              -a \
                                                \( -c $a \) \
                                            -o \
                                              $a -lt $a \
                                            -o \
                                              $a \< $a \
                                          \) \
                                        -a \
                                          $a -ne $a \
                                        -a \
                                          $a \> $a \
                                      -o \
                                        \( -h $a \) \
                                    \) \
                                  -a \
                                    $a -ef $a \
                                -o \
                                  -z $a \
                                -o \
                                  -G $a \
                              \) \
                            -a \
                              $a -gt $a \
                            -a \
                              \( \( -u $a \) \) \
                          -o \
                            -w $a \
                          -o \
                            ! \( -k $a \) \
                        \) \
                      -a \
                        \( \
                            $a = $a \
                          -o \
                            -d $a \
                        \) \
                    -o \
                      -O $a \
                  \) \
                -a \
                  ! -g $a \
              -o \
                -s $a \
            \) \
          -a \
            -e $a \
          -a \
            -n $a \
        -o \
          $a -ge $a \
      \) \
    -a \
      -r $a \
  -o \
    $a != $a \
  -o \
    ! \( ! ! -f $a \) \
  -o \
    $a -ot $a \
  -o \
    $a -nt $a \
  -o \
    -L $a \
  -o \
    ! \( \
        -t $a \
      -o \
        $a \
    \) \
]

# Same as above
[ \
      \( \
            \( \
                  \( \
                        \( \
                              \( \
                                    \( \
                                          \( \
                                                \( \
                                                      \( \
                                                          -x $a \
                                                        -o \
                                                          -p $a \
                                                      \) \
                                                    -a \
                                                      ! ! $a -le $a \
                                                  -o \
                                                    ! -b $a \
                                                \) \
                                              -a \
                                                $a -eq $a \
                                              -a \
                                                $a \
                                              -a \
                                                ! ! \( -S $a \) \
                                              -a \
                                                \( -c $a \) \
                                            -o \
                                              $a -lt $a \
                                            -o \
                                              $a \< $a \
                                          \) \
                                        -a \
                                          $a -ne $a \
                                        -a \
                                          $a \> $a \
                                      -o \
                                        \( -h $a \) \
                                    \) \
                                  -a \
                                    $a -ef $a \
                                -o \
                                  -z $a \
                                -o \
                                  -G $a \
                              \) \
                            -a \
                              $a -gt $a \
                            -a \
                              \( \( -u $a \) \) \
                          -o \
                            -w $a \
                          -o \
                            ! \( -k $a \) \
                        \) \
                      -a \
                        \( \
                            $a = $a \
                          -o \
                            -d $a \
                        \) \
                    -o \
                      -O $a \
                  \) \
                -a \
                  ! -g $a \
              -o \
                -s $a \
            \) \
          -a \
            -e $a \
          -a \
            -n $a \
        -o \
          $a -ge $a \
      \) \
    -a \
      -r $a \
  -o \
    $a != $a \
  -o \
    ! \( ! ! -f $a \) \
  -o \
    $a -ot $a \
  -o \
    $a -nt $a \
  -o \
    -L $a \
  -o \
    ! \( \
        -t $a \
      -o \
        $a \
    \) \
]
