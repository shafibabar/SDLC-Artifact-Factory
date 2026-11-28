# Portable Scripts: Linux and macOS

Every script this plugin ships runs on a user's machine, and that machine is as likely to be a Mac as a Linux box. The two differ in three places: the shell (macOS ships **Bash 3.2**; Linux has Bash 5), the text tools (macOS has **BSD** `sed`, `awk` and `grep`; Linux has GNU), and the file system (macOS ignores letter case and keeps `/tmp` as a link into `/private`). A script must give the same result on both.

The dangerous differences are the **silent** ones: the command exits 0 and produces something else, so a test written on one system passes for the wrong reason on the other. Each row below was observed on stock macOS with nothing from Homebrew on the `PATH`.

## What breaks, and what to write instead

| Linux-only | On stock macOS | Write instead |
|---|---|---|
| `sed -i 's/a/b/' f` | Error: the script is read as a backup suffix | `sed 's/a/b/' f > f.tmp && mv f.tmp f` |
| `\s` `\w` `\b` in a sed pattern | **Silent**: no match | `[[:space:]]`, `[[:alnum:]_]`; for a word boundary, match the neighbours |
| `\+`, `\?` or a backslashed alternation bar in sed without `-E` | **Silent**: no match | `sed -E`, where `+`, `?` and the alternation bar need no backslash |
| `\n` in a sed replacement | **Silent**: prints the letter `n` | awk, or a backslash followed by a real line break |
| `\U` `\L` in a sed replacement | **Silent**: prints the letter | `awk '{ print toupper($0) }'`, or `tr '[:lower:]' '[:upper:]'` |
| `sed '0,/re/…'` | Error: no line 0 | `1,/re/` when line 1 cannot match, otherwise awk |
| `sed '/x/{…d}'` | Error | End the last command with `;` before `}` |
| `grep -P` | Error | `grep -E` with POSIX classes |
| awk `gensub`, `asort`, `strftime`, three-argument `match` | Error | POSIX awk: `sub`, `gsub`, `match` with `RSTART`/`RLENGTH`, `substr` |
| awk `IGNORECASE`, `\<` `\>` | **Silent**: ignored | `tolower($0) ~ /…/` |
| `mapfile`, `readarray` | Error | `while IFS= read -r line; do a+=("$line"); done < file` |
| `declare -A` (name → value table) | Error | A `case` statement, or do the lookup in awk or Python |
| `${x,,}` `${x^^}` | Error | `tr '[:upper:]' '[:lower:]'` |
| The `&` forms of pipe and append (pipe-ampersand, `&>>`) | Syntax error: the whole script fails to start | `cmd 2>&1` before the pipe; `>> f 2>&1` |
| `source <(cmd)` | **Silent**: sources nothing | Write to a temporary file and source that |
| `"${a[@]}"` on an empty array under `set -u` | Error: "unbound variable" | `${a[@]+"${a[@]}"}` |
| `${x/"$old"/"$new"}` | **Silent**: the quotes land in the result | `${x%%"$old"*}$new${x#*"$old"}` |
| `timeout`, `tac`, `nproc`, `shuf` | Command not found | awk or a short Python program (macOS's own `tail -r` is not on Linux either) |
| `stat -c`, `date -d`, `find -printf`, `head -n -1`, `mktemp --suffix` | Error | Python, or the POSIX form of the command |
| `echo "$out" \| grep -q x` in a script that sets `pipefail` | **Silent, and on Linux too**: now and then the match counts as a failure (`grep -q` exits early, the writer dies on the closed pipe) | `… \| grep x >/dev/null`, or `grep -q x <<<"$out"` |
| `wc -l` output compared as text | **Silent**: BSD pads it with spaces | Compare as a number (`-eq`), or strip with `tr -d ' '` |
| A path compared with one that was resolved | **Silent**: `/tmp/x` is not under `/private/tmp` | Resolve both sides (`Path.resolve()`, `cd … && pwd -P`) |
| "`SKILL.md` exists" as a test for the exact name | **Silent**: `skill.md` answers too | List the folder and compare the names |

## Rules

1. **Target Bash 3.2 and POSIX tools.** `#!/bin/bash` is Bash 3.2 on every Mac, whatever else is installed.
2. **When a text change is more than a simple substitution, embed Python.** `python3` is already required by this plugin; a here-document of Python behaves the same everywhere. Most validators in this repository are written this way.
3. **A test must not lean on a Linux-only tool to build its fixtures.** The harness (`tests/lib/harness.sh`) offers `sed_in_place`, `sed_multiline` and `run_with_timeout` for exactly this.
4. **Run the check.** `python3 scripts/lint-portability.py <script>` (blocking in the governance gate) flags the constructs above that a line scan can see; the empty-array row and the last three rows of the table it cannot, so the tests also run on both systems in CI.
5. **A guarded use is allowed.** A GNU command used only after `command -v` finds it carries `# portable-ok: <reason>` on its line, which silences the check for that line.

This covers the plugin's own scripts. Scripts the plugin *generates for a product* run in Linux containers and follow that product's standards.
