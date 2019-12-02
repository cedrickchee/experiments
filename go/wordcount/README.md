# Word Count

Word count program, _wc_ implemented in Go language.

## Micro Benchmarking & Comparison

Compare elapsed time and maximum memory size.

```sh
# wc
$ time -f "%es %MKB" wc large-file-100mb.txt
   409495   2321508 104857600 large-file-100mb.txt
3.75s 1984KB

# A naive approach
$ time -f "%es %MKB" naive large-file-100mb.txt
409495 2399739 104857600 large-file-100mb.txt
0.83s 1480KB

# Splitting the input
$ time -f "%es %MKB" chunks large-file-100mb.txt
409495 2399710 104857600 large-file-100mb.txt
0.26s 1440KB

# Concurrent
$ time -f "%es %MKB" channel large-file-100mb.txt
410991 2401598 104857600 large-file-100mb.txt
0.24s 1316KB

# Improved concurrent
$ time -f "%es %MKB" mutex large-file-100mb.txt
409495 2399710 104857600 large-file-100mb.txt
0.15s 1560KB
```

## Project Setup

First, create large text file.

Please note, the commands below will create unreadable files. You'll then be able to read the number of lines in that file using `wc -l large-file.100mb.txt`.

- Create a 100MB file:

```sh
$ dd if=/dev/urandom of=large-file-100mb.txt count=1024 bs=102400
```

- Create a 1GB file:

```sh
$ dd if=/dev/zero of=large-file-1gb.txt count=1024 bs=1048576
```

Alternatively, you can use the test data from the `data` directory.
