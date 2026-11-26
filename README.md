# KShell — a simple Unix shell in C

KShell is a small Unix shell written in C for an Operating Systems course. The whole shell is **one file**, [01_Source_Code/main.c](01_Source_Code/main.c), about 140 lines, so it can be read from top to bottom.

It uses only the C standard library and POSIX system calls, and compiles with `gcc -Wall -Wextra` with zero warnings.

---

## Project layout

```
SE25UCSE084_Naga Sai Karthikeya_OS_Project/
├── 01_Source_Code/
│   ├── main.c                  the shell's source code
│   ├── Makefile                builds ./kshell; "make test" runs the tests
│   └── supporting_files/
│       ├── test_basic.sh       automated command tests
│       ├── leak_check.sh       memory leak check (valgrind)
│       ├── sample.txt          sample file for cat / grep / sort demos
│       └── TRY_THESE.txt       commands to type during the demo
├── 02_Project_Report/          Project_Report.pdf
├── 03_Test_Cases/              Test_Cases.pdf
├── 04_Execution_Screenshots/   Output1.png, Output2.png, Output3.png
└── 05_README/                  README.md (this file)
```

---

## What is a shell?

A shell is an ordinary program that sits between you and the operating system kernel. It repeats one loop forever:

1. **Read** a line you type.
2. **Parse** it into a program name and its arguments.
3. **Execute** it by asking the kernel to create a new process and run the program in it, then wait for it to finish.

The shell does not run `ls` itself. It asks the kernel to create a process (`fork`), load `ls` into it (`execvp`), and tell it when it is done (`waitpid`).

---

## Features

| Feature | How it works |
|---|---|
| Prompt `kshell> ` and a read–parse–execute loop | `printf` + `fgets` in `main()` |
| Splits input into command + arguments, ignoring extra spaces and tabs | `strtok()` in `parse()` |
| Runs any program, e.g. `ls -l`, `sort sample.txt` | `fork()` → `execvp()` → `waitpid()` in `execute()` |
| `cd [dir]` (no argument goes to the home directory) | `chdir()`, `getenv("HOME")` |
| `pwd` | `getcwd()` |
| `exit [n]`, and Ctrl+D (end of input) also exits | leaves the loop |
| Error messages: `kshell: <cmd>: command not found`, failed `cd` | checks `errno`, uses `perror()` |
| Empty input just shows the prompt again | `count == 0` check |

---

## OS concepts covered

| OS concept | What it means here | System calls |
|---|---|---|
| **Process creation** | The shell makes a copy of itself to run each command | `fork()` |
| **Program loading** | The copy replaces itself with the requested program, found through `$PATH` | `execvp()` |
| **Process synchronisation** | The shell waits for the command to finish before showing the next prompt | `waitpid()` |
| **Process termination and zombies** | A finished child stays a "zombie" until its parent collects its exit status, so the shell always waits for it | `waitpid()`, `_exit()` |
| **Process state** | The current directory belongs to each process, so `cd` must run inside the shell itself, not in a child | `chdir()`, `getcwd()` |
| **Environment** | The home directory is read from an environment variable | `getenv("HOME")` |
| **File descriptors** | A child inherits stdin (0), stdout (1) and stderr (2), which is why its output appears in the same terminal | inherited across `fork()` |

### The fork → exec → wait cycle

```
      shell (parent)
          |
        fork()  ─────────────►  child (copy of the shell)
          |                          |
      waitpid()  (waits)        execvp("ls", argv)
          |                          |   the child becomes "ls"
          |                          ▼
          |                      ls runs, then exits
          ◄──────── exit status ─────┘
      prints the next prompt
```

---

## How the code is organised

Everything is in `main.c`, in this order:

| Function | Job |
|---|---|
| `parse()` | Splits `"ls   -l  /tmp"` into `{"ls", "-l", "/tmp", NULL}`, the format `execvp()` expects |
| `execute()` | The fork → exec → wait cycle; prints "command not found" if `execvp()` fails |
| `main()` | The loop: print prompt, read line, parse, then handle `exit`, `cd` (`chdir()`, `$HOME` if no folder) and `pwd` (`getcwd()`) itself, or call `execute()` for anything else |

**Why are `cd`, `pwd` and `exit` built in?** `fork()` gives the child its own copy of the shell's state. If `cd` ran in a child, only the child's directory would change and the shell would stay where it was. `exit` has to end the shell itself, so it can't run in a child either.

**Why `_exit()` and not `exit()` in the child?** `exit()` flushes the stdio buffers the child copied from the shell. When input comes from a file, that moves the shared file position back and the shell runs some commands twice. `_exit()` ends the child immediately without touching those buffers.

---

## Build and run

You need a C compiler (`gcc` or `clang`) and `make`, on Linux or macOS.

```bash
cd 01_Source_Code
```

```bash
make
```

```bash
./kshell
```

Without `make`:

```bash
gcc -std=c11 -Wall -Wextra -o kshell main.c
```

`make clean` removes the compiled program.

### Demo commands

Run the shell from `supporting_files/` so `sample.txt` is in the current directory:

```bash
cd supporting_files && ../kshell
```

[TRY_THESE.txt](01_Source_Code/supporting_files/TRY_THESE.txt) lists commands to type.

---

## Sample session

Run from `01_Source_Code/supporting_files/`:

```text
kshell> ls
TRY_THESE.txt
leak_check.sh
sample.txt
test_basic.sh
kshell> grep CSE sample.txt
101 Ravi    CSE 85
103 Arjun   CSE 78
106 Divya   CSE 95
109 Vikram  CSE 88
kshell> sort -k4 -n sample.txt
107 Rahul   CIVIL 59
104 Sneha   MECH 66
110 Anjali  MECH 70
108 Meena   ECE 74
103 Arjun   CSE 78
105 Kiran   ECE 81
101 Ravi    CSE 85
109 Vikram  CSE 88
102 Priya   ECE 92
106 Divya   CSE 95
kshell> wc -l sample.txt
      10 sample.txt
kshell> echo   hello     world
hello world
kshell> cd /no/such/folder
kshell: cd: /no/such/folder: No such file or directory
kshell> abc
kshell: abc: command not found
kshell> exit
```

---

## Tests

From `01_Source_Code/`:

```bash
make test
```

This builds the shell if needed, then runs:

| Test file | What it checks |
|---|---|
| `supporting_files/test_basic.sh` | 26 tests: prompt, running commands, extra spaces, `cd`, `pwd`, `exit`, error messages, empty input, Ctrl+D, no repeated commands after a failed one |
| `supporting_files/leak_check.sh` | Memory leaks, using `valgrind` on Linux or `leaks` on macOS |

The full test case table (18 cases with expected and actual output) is in [03_Test_Cases/Test_Cases.pdf](03_Test_Cases/Test_Cases.pdf).

---

## Limitations

These are left out on purpose to keep the shell simple:

- No pipes (`|`), redirection (`>`, `<`), background jobs (`&`), or job control (`fg`, `bg`, Ctrl+Z).
- No quotes, so `"hello world"` is two arguments.
- No signal handling, so Ctrl+C at the prompt ends KShell itself.
- No history or arrow-key editing.
- At most 1023 characters per line and 63 words per command.
