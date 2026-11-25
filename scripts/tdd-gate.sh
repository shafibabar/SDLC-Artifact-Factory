#!/bin/bash
# tdd-gate.sh — PreToolUse hook, matcher: Write|Edit
# Purpose: block writing or editing a Go, TypeScript or Python implementation
#          file that has no matching test file already on disk (TDD: tests
#          first, always — an Edit is a change too, #1288). It is an EXISTENCE
#          check only: it never compares timestamps, commits or test contents.
# Contract: JSON on stdin (PreToolUse schema). Exit 0 to allow, JSON with
#           hookSpecificOutput.permissionDecision:"deny" + reason to block.
# Accepted test locations, for an implementation file <dir>/<stem>.<ext>
# (<variant> is one of the names in VARIANTS):
#   Go      <dir>/<stem>_test.go, <dir>/<stem>_<variant>_test.go
#   TS/TSX  <stem>.test|spec.ts|tsx and <stem>.<variant>.test|spec.ts|tsx,
#           in <dir> or <dir>/__tests__
#   Python  test_<stem>.py, <stem>_test.py (also with _<variant>), in <dir>, or
#           mirrored under <project root>/tests/ (optionally under unit/,
#           integration/, contract/ or e2e/; a leading src/ and package name
#           may be dropped from the mirrored path)
# Exempt, deliberately narrowly (D048):
#   - test-support folders: tests/, test/ at the project root; internal/test/
#     (Go); src/test/ (TS); __tests__, __mocks__, __fixtures__ (TS); testdata/
#     (Go); mocks/*_mock.go
#   - named tool configuration and test-setup files; *.d.ts
#   - conftest.py (not under src/, unless in a tests folder)
#   - migration files (by file-name shape, inside migrations/ or alembic/)
#   - entry, index and __init__.py files ONLY while their content is thin
#     (re-exports, or wiring with no classes and a line cap): see thin_* below.
# The "project root" is the nearest ancestor holding go.mod, package.json,
# pyproject.toml, setup.cfg or .git.
# Applies to code the plugin generates for a product — this repo's own Python
# tooling is only affected when the plugin is enabled while editing it.
set -euo pipefail

# The program is read from fd 3 so the payload stays on stdin: passing a large
# Write payload as an argument exceeds the OS argument limit, and the resulting
# error would not block the write.
exec python3 /dev/fd/3 3<<'PYEOF'
import ast, json, os, re, sys

VARIANTS = ("unit", "integration", "e2e", "contract", "bench", "fuzz", "internal",
            "race", "property", "chaos", "load", "perf", "example", "a11y",
            "accessibility", "snapshot", "visual")
ROOT_MARKERS = ("go.mod", "package.json", "pyproject.toml", "setup.cfg", ".git")
TS_CONFIG = re.compile(
    r"^((vite|vitest|playwright|jest|eslint|prettier|tailwind|postcss|babel|webpack|"
    r"rollup|rspack|rsbuild|tsup|commitlint|stylelint|orval|openapi-ts|"
    r"module-federation|cypress|storybook)(\.[a-z0-9-]+)?\.config|vitest\.workspace)\.tsx?$")
TS_SETUP = {"setupTests.ts", "setupTests.tsx", "vitest.setup.ts", "jest.setup.ts", "test-setup.ts"}
GO_MAIN_MAX, TS_ENTRY_MAX, PY_ENTRY_MAX = 100, 40, 60

def allow():
    print(json.dumps({"continue": True}))
    sys.exit(0)

def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)

try:
    payload = json.load(sys.stdin)
    tool_input = payload.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
except Exception:
    # Malformed/unexpected stdin — fail open, never crash a hook.
    allow()

ext = os.path.splitext(file_path)[1]
if ext not in (".go", ".ts", ".tsx", ".py"):
    allow()  # not a Go/TypeScript/Python file — not in scope

# Normalised, so "tests/../src/x.py" cannot borrow the tests/ exemption.
path = file_path.replace("\\", "/")
if not os.path.isabs(path):
    path = os.path.join(payload.get("cwd") or os.getcwd(), path)
path = os.path.normpath(path)
directory, name = os.path.split(path)
stem = name[:-len(ext)]

# --- the file IS a test
if ext == ".go" and name.endswith("_test.go"):
    allow()
if ext in (".ts", ".tsx") and re.search(r"\.(test|spec)\.tsx?$", name):
    allow()
if ext == ".py" and (name.startswith("test_") or name.endswith("_test.py")):
    allow()

def find_root(start):
    here = start
    while True:
        if any(os.path.exists(os.path.join(here, m)) for m in ROOT_MARKERS):
            return here
        parent = os.path.dirname(here)
        if parent == here:
            return None
        here = parent

root = find_root(directory)
rel = os.path.relpath(path, root).split(os.sep) if root else None
dirs = path.split("/")[:-1]                      # every folder name
rel_dirs = rel[:-1] if rel else []               # folders below the project root

# --- content, as it will be after this Write/Edit (for the thin-file checks)
def resulting_content():
    if isinstance(tool_input.get("content"), str):
        return tool_input["content"]
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            current = fh.read()
    except OSError:
        return None
    old, new = tool_input.get("old_string", ""), tool_input.get("new_string", "")
    if not old or old not in current:
        return current
    return current.replace(old, new) if tool_input.get("replace_all") else current.replace(old, new, 1)

TOKENS = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|`(?:\\.|[^`\\])*`', re.S)

def strip_comments_and_strings(text):
    return TOKENS.sub(lambda m: " " if m.group(0).startswith("/") else '""', text)

def line_count(text):
    return sum(1 for line in text.splitlines() if line.strip())

def thin_go_main(text):
    """package main, only func main / func run, no types, methods or closures
    declared at top level, and short."""
    code = strip_comments_and_strings(text)
    if not re.search(r"^package\s+main\b", code, re.M) or re.search(r"^type\b", code, re.M):
        return False
    depth = 0
    for line in code.splitlines():
        if depth == 0 and re.search(r"\bfunc\b", line) and not re.match(r"func\s+(main|run)\s*\(", line):
            return False
        depth += line.count("{") - line.count("}")
    body = re.sub(r"^import\s*\([^)]*\)", "", code, flags=re.M)
    return line_count(body) <= GO_MAIN_MAX

TS_IMPORT = r"""import\s+(?:type\s+)?(?:[\w$\s,*{}]+?\s+from\s+)?(?:"[^"]*"|'[^']*')\s*;?"""
TS_BARREL = [
    TS_IMPORT,
    r"""export\s+(?:type\s+)?(?:\*(?:\s+as\s+[\w$]+)?|\{[^{}]*\})\s+from\s+(?:""|'')\s*;?""",
    r"""export\s+(?:type\s+)?\{[^{}]*\}\s*;?""",
    r"""(?:void\s+)?import\(\s*(?:""|'')\s*\)\s*;?""",
]

def ts_barrel(text):
    """Nothing but imports and re-exports."""
    code = strip_comments_and_strings(text).strip()
    while code:
        for pattern in TS_BARREL:
            m = re.match(pattern, code)
            if m:
                code = code[m.end():].strip()
                break
        else:
            return False
    return True

def thin_ts_entry(text):
    """Start-up wiring: no declarations of functions or classes, no loops, no
    switch, no exports, and short."""
    code = re.sub(TS_IMPORT, "", strip_comments_and_strings(text))
    if re.search(r"(?<![\w$.])(function|class|for|while|switch|export)(?![\w$])", code):
        return False
    return line_count(code) <= TS_ENTRY_MAX

def parse_python(text):
    try:
        return ast.parse(text)
    except (SyntaxError, ValueError):
        return None

def is_docstring(node):
    return isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant) and isinstance(node.value.value, str)

def has(node, kinds):
    return any(isinstance(child, kinds) for child in ast.walk(node))

def thin_init(text):
    """Docstring, imports and plain assignments (dunders, or literal values)."""
    tree = parse_python(text)
    if tree is None:
        return False

    def ok(node):
        if isinstance(node, (ast.Import, ast.ImportFrom)) or is_docstring(node):
            return True
        if isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
            targets = node.targets if isinstance(node, ast.Assign) else [node.target]
            if not all(isinstance(t, ast.Name) for t in targets) or node.value is None:
                return False
            if has(node.value, (ast.Lambda, ast.ListComp, ast.SetComp, ast.DictComp,
                                ast.GeneratorExp, ast.IfExp)):
                return False
            if all(t.id.startswith("__") and t.id.endswith("__") for t in targets):
                return True
            try:
                ast.literal_eval(node.value)
                return True
            except (ValueError, TypeError):
                return False
        if isinstance(node, ast.If) and "TYPE_CHECKING" in ast.dump(node.test):
            return not node.orelse and all(isinstance(n, (ast.Import, ast.ImportFrom)) for n in node.body)
        return False

    return all(ok(node) for node in tree.body)

def thin_py_entry(text):
    """Imports, calls, assignments, `if __name__` and def main/run only; short."""
    tree = parse_python(text)
    if tree is None or has(tree, (ast.ClassDef, ast.Lambda)):
        return False

    def ok(node):
        if isinstance(node, (ast.Import, ast.ImportFrom, ast.Assign, ast.AnnAssign, ast.Raise)):
            return True
        if is_docstring(node):
            return True
        if isinstance(node, ast.Expr):
            return isinstance(node.value, (ast.Call, ast.Await))
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            return node.name in ("main", "run")
        if isinstance(node, ast.If) and "__name__" in ast.dump(node.test):
            return not node.orelse and all(ok(n) for n in node.body)
        return False

    lines = sum(1 for l in text.splitlines() if l.strip() and not l.strip().startswith("#"))
    return all(ok(node) for node in tree.body) and lines <= PY_ENTRY_MAX

# --- exemptions
def exempt():
    top = rel_dirs[0] if rel_dirs else None
    if top in ("tests", "test"):
        return True
    folders = rel_dirs if rel else dirs
    if "migrations" in folders or "alembic" in folders:
        parent = dirs[-1] if dirs else ""
        if ext == ".py" and (re.match(r"^\d+\w*\.py$", name) or parent == "versions"
                             or (name == "env.py" and parent in ("migrations", "alembic"))):
            return True
        if ext == ".go" and (re.match(r"^\d+\w*\.go$", name) or (name == "embed.go" and parent == "migrations")):
            return True

    if ext == ".go":
        if rel_dirs[:2] == ["internal", "test"] or "testdata" in dirs:
            return True
        if name.endswith("_mock.go") and dirs and dirs[-1] == "mocks":
            return True
        if name == "main.go" and (rel == ["main.go"] or "cmd" in (rel_dirs if rel else dirs)):
            text = resulting_content()
            return text is not None and thin_go_main(text)
        return False

    if ext in (".ts", ".tsx"):
        if name.endswith(".d.ts"):
            return True
        if rel_dirs[:2] == ["src", "test"] or {"__tests__", "__mocks__", "__fixtures__"} & set(dirs):
            return True
        if name in TS_SETUP:
            return True
        if TS_CONFIG.match(name) and "src" not in (rel_dirs if rel else dirs):
            return True
        if stem in ("index", "main", "bootstrap"):
            text = resulting_content()
            if text is None:
                return False
            if ts_barrel(text):
                return True
            at_entry_point = rel == [name] or bool(dirs and dirs[-1] == "src")
            return at_entry_point and thin_ts_entry(text)
        return False

    # Python
    if name == "conftest.py":
        folders = rel_dirs if rel else dirs
        return "src" not in folders or bool({"tests", "test"} & set(folders))
    if rel and rel in (["setup.py"], ["noxfile.py"], ["gunicorn.conf.py"]):
        return True
    if name == "locustfile.py":
        return True
    if name in ("__init__.py", "__main__.py", "main.py"):
        text = resulting_content()
        if text is None:
            return False
        return thin_init(text) if name == "__init__.py" else thin_py_entry(text)
    return False

if exempt():
    allow()

# --- is there a matching test?
stems = [stem] + [f"{stem}_{v}" for v in VARIANTS]
if ext == ".go":
    candidates = [os.path.join(directory, f"{s}_test.go") for s in stems]
    expected = candidates[0]
elif ext in (".ts", ".tsx"):
    names = [f"{stem}{v}.{kind}{e}"
             for v in [""] + [f".{v}" for v in VARIANTS]
             for kind in ("test", "spec")
             for e in (ext, ".tsx" if ext == ".ts" else ".ts")]
    candidates = [os.path.join(d, n) for d in (directory, os.path.join(directory, "__tests__")) for n in names]
    expected = os.path.join(directory, f"{stem}.test{ext}")
else:
    folders = [directory]
    base = root
    if base is None and "src" in dirs:
        base = "/".join(dirs[:len(dirs) - 1 - dirs[::-1].index("src")]) or "/"
    if base:
        sub = os.path.relpath(directory, base).split(os.sep)
        sub = [] if sub == ["."] else sub
        mirrors = [sub]
        if sub[:1] == ["src"]:
            mirrors += [sub[1:], sub[2:]]
        elif sub:
            mirrors.append(sub[1:])
        folders += [os.path.join(base, "tests", layer, *m)
                    for m in mirrors for layer in ("", "unit", "integration", "contract", "e2e")]
    names = [n for s in stems for n in (f"test_{s}.py", f"{s}_test.py")]
    candidates = [os.path.join(d, n) for d in folders for n in names]
    expected = f"{os.path.join(directory, f'test_{stem}.py')}, or a mirrored path such as tests/unit/.../test_{stem}.py"

if any(os.path.isfile(c) for c in candidates):
    allow()

deny(
    f"No test file found for {file_path} (expected {expected} to already exist). "
    f"TDD is non-negotiable in this plugin: write the failing test first, then the "
    f"implementation. Create the test file before this one."
)
PYEOF
