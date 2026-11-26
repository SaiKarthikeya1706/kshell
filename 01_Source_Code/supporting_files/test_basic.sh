#!/usr/bin/env bash
# test_basic.sh - automated tests for KShell
#
# Each test sends some commands to ./kshell on stdin, saves the output,
# and checks it.   Run with:  make test   (or: bash supporting_files/test_basic.sh)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN=${1:-$ROOT/kshell}
[ -x "$BIN" ] || { echo "kshell not built, run make in 01_Source_Code"; exit 1; }

PASS=0
FAIL=0

# scratch folder for the tests, deleted at the end
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kshell-tests.XXXXXX")
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home" "$WORK/a"
echo data > "$WORK/a/file1.txt"

section() { printf '\n== %s ==\n' "$1"; }
pass()    { PASS=$((PASS + 1)); echo "  PASS  $1"; }
fail()    {
    FAIL=$((FAIL + 1)); echo "  FAIL  $1"; echo "        $2"
    printf '%s\n' "$OUT" | sed 's/^/        | /' | head -20
}

# run_shell "commands"  -> runs kshell inside $WORK, sets OUT and RC
# a watchdog kills the shell after 10 seconds in case it hangs
run_shell() {
    printf '%s' "$1" > "$WORK/.input"
    ( cd "$WORK" && exec "$BIN" < "$WORK/.input" > "$WORK/.out" 2>&1 ) &
    local pid=$!
    ( sleep 10; kill -9 "$pid" 2>/dev/null ) &
    local dog=$!
    wait "$pid"; RC=$?
    kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null
    OUT=$(cat "$WORK/.out")
    [ "$RC" -eq 137 ] && OUT="$OUT
TIMEOUT"
}

assert_contains()     { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then pass "$1"; else fail "$1" "expected: $2"; fi; }
assert_not_contains() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then fail "$1" "did not expect: $2"; else pass "$1"; fi; }
assert_rc()           { if [ "$RC" = "$2" ]; then pass "$1"; else fail "$1" "expected exit code $2, got $RC"; fi; }


section "Prompt and read-parse-execute loop"
run_shell $'echo hello\n'
assert_contains "prompt 'kshell> ' is printed" "kshell> "
assert_contains "external command runs (fork/execvp/waitpid)" "hello"
run_shell $'echo one\necho two\necho three\n'
assert_contains "loop runs several commands in order" $'one\nkshell> two\nkshell> three'

section "Parsing"
run_shell $'echo    lots     of      spaces\n'
assert_contains "multiple spaces between arguments" "lots of spaces"
run_shell $'echo\ttabs\t\tseparate\n'
assert_contains "tabs separate arguments" "tabs separate"
run_shell $'   echo leading-and-trailing   \n'
assert_contains "leading/trailing spaces ignored" "leading-and-trailing"
run_shell $'ls a\n'
assert_contains "command with an argument (ls a)" "file1.txt"
LONG=$(printf 'x%.0s' $(seq 1 1000))
run_shell "echo $LONG"$'\n'
assert_contains "long line (1000 chars)" "$LONG"

section "Built-ins"
run_shell $'pwd\n'
assert_contains "pwd prints current directory" "$WORK"
run_shell $'cd a\npwd\n'
assert_contains "cd changes the shell's directory" "$WORK/a"
run_shell $'cd ..\npwd\n'
assert_contains "cd .. goes up" "$(dirname "$WORK")"
OUT=$(cd "$WORK" && HOME="$WORK/home" "$BIN" <<< $'cd\npwd\n' 2>&1)
assert_contains "cd with no argument goes to \$HOME" "$WORK/home"
run_shell $'exit\necho should-not-run\n'
assert_not_contains "exit stops the shell" "should-not-run"
assert_rc "exit returns status 0" 0
run_shell $'exit 7\n'
assert_rc "exit 7 returns status 7" 7

section "Error handling"
run_shell $'notacommand\necho still-alive\n'
assert_contains "unknown command message" "kshell: notacommand: command not found"
assert_contains "shell keeps running after unknown command" "still-alive"
run_shell $'notacommand\necho once\n'
assert_contains "commands after a failed one run only once" $'once\nkshell> \n'
run_shell $'cd /no/such/dir\necho after-cd\n'
assert_contains "failed cd reports error" "kshell: cd: /no/such/dir: No such file or directory"
assert_contains "shell keeps running after failed cd" "after-cd"
run_shell $'\n\n   \n\t\necho after-blank\n'
assert_not_contains "empty input gives no error" "command not found"
assert_contains "empty input just shows the prompt again" "after-blank"
run_shell $'ls /no/such/path\necho next\n'
assert_contains "failing program's error is shown" "No such file"
assert_contains "shell continues after a failing program" "next"

section "End of input (Ctrl+D)"
run_shell $'echo bye\n'
assert_rc "EOF exits cleanly" 0
assert_not_contains "EOF does not hang" "TIMEOUT"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
