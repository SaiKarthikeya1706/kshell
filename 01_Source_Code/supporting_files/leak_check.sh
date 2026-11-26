#!/usr/bin/env bash
# leak_check.sh — check KShell for memory leaks.
#
# Uses valgrind when it is installed (Linux).  On macOS, where valgrind is
# not available, it uses Apple's `leaks` tool on a copy of the binary signed
# with the get-task-allow entitlement (which `leaks` needs to inspect it).
#
# The workload avoids "command not found": under `leaks --atExit` a child
# that exits without running a program gets frozen by the tool and the run
# hangs.  test_basic.sh covers that case instead.
set -u
TESTS_DIR=$(cd "$(dirname "$0")" && pwd)
BIN="$(dirname "$TESTS_DIR")/kshell"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kshell-leaks.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 1

printf 'echo a   b\npwd\ncd /tmp\ncd /nonexistent\n\n   \nls\ncd\nexit\n' > input.txt

echo "== Memory leak check =="
if command -v valgrind >/dev/null 2>&1; then
    if valgrind --leak-check=full --errors-for-leak-kinds=definite,indirect \
                --error-exitcode=99 "$BIN" < input.txt > leak.log 2>&1; then
        echo "  PASS  valgrind reports no leaks"
    else
        echo "  FAIL  valgrind found problems:"; tail -30 leak.log; exit 1
    fi
elif command -v leaks >/dev/null 2>&1; then
    cp "$BIN" ./kshell.bin
    cat > ent.plist <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.security.get-task-allow</key><true/></dict></plist>
PL
    codesign -s - -f --entitlements ent.plist ./kshell.bin >/dev/null 2>&1
    perl -e 'alarm 60; exec @ARGV' leaks --atExit -- ./kshell.bin < input.txt > leak.log 2>&1
    LINE=$(grep -E "leaks for .* total leaked bytes" leak.log)
    if printf '%s' "$LINE" | grep -q ": 0 leaks for 0 total leaked bytes"; then
        echo "  PASS  ${LINE#*: }"
    else
        echo "  FAIL  ${LINE:-leaks did not finish}"; grep -A5 "Leak:" leak.log | head -40; exit 1
    fi
else
    echo "  SKIP  neither valgrind nor leaks is installed"
fi
