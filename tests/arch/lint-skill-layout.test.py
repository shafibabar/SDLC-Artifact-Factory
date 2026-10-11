#!/usr/bin/env python3
"""
tests/arch/lint-skill-layout.test.py — contract for scripts/lint-skill-layout.py
(Fresh-Eyes A3, closes #1227).

Builds synthetic skills in a temp dir and asserts each rule fires on its
violation and stays quiet on the compliant shape:
  L1 entry file  · L2 folder names · L3 empty dirs · L4 reachability · L5 paths
plus: pointer forms that count (folder-rooted, ./x, markdown link, backticked
sibling, transitive), content that must NOT be flagged (example absolute paths,
CLAUDE_PLUGIN_ROOT to repo-root scripts), purity, and the live-tree smoke run.

Standalone:  python3 tests/arch/lint-skill-layout.test.py
"""
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "lint-skill-layout.py"

spec = importlib.util.spec_from_file_location("_lint_skill_layout_under_test", MODULE_PATH)
L = importlib.util.module_from_spec(spec)
spec.loader.exec_module(L)

passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: lint-skill-layout ({name})")
        passed += 1
    else:
        print(f"FAIL: lint-skill-layout ({name})")
        failed.append(name)


def make(root: Path, files: dict[str, str], dirs: tuple[str, ...] = ()) -> Path:
    """Create skills/fx/ under root with the given relative files and dirs."""
    sk = root / "skills" / "fx"
    sk.mkdir(parents=True)
    for rel, text in files.items():
        p = sk / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
    for d in dirs:
        (sk / d).mkdir(parents=True, exist_ok=True)
    return sk


def rules(findings):
    return sorted(f["rule"] for f in findings)


FM = "---\nname: fx\n---\n"

# --- a compliant skill: every pointer form reaches its file -----------------
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {
        "SKILL.md": FM + "Read `references/guide.md` first. Copy ./templates/out.md.\n"
                         "Run [the scaffold](scripts/scaffold.sh).\n",
        "references/guide.md": "Deeper detail lives in `detail.md` and ../examples/big.md\n",
        "references/detail.md": "See [the example](../examples/small.md).\n",
        "examples/small.md": "x\n",
        "examples/big.md": "x\n",
        "templates/out.md": "x\n",
        "scripts/scaffold.sh": 'TEMPLATE="$SKILL_DIR/assets/logo.txt"\n',
        "assets/logo.txt": "x\n",
    })
    clean = L.lint_skill(sk)
check("compliant skill has ZERO findings", clean == [])
check("folder-rooted, ./x, markdown link, backtick sibling and transitive pointers all count",
      clean == [])

# --- L1 entry file -----------------------------------------------------------
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"skill.md": FM})
    f = L.lint_skill(sk)
check("L1: lowercase skill.md is flagged", "L1" in rules(f))
check("L1: a missing SKILL.md is reported", any("missing SKILL.md" in x["message"] for x in f))
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM, "NOTES.md": "stray"})
    f = L.lint_skill(sk)
check("L1: a stray file at the root is flagged", rules(f) == ["L1"])

# --- L2 folder names ---------------------------------------------------------
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM + "see docs/a.md\n", "docs/a.md": "x"})
    f = L.lint_skill(sk)
check("L2: a non-spec folder is flagged", "L2" in rules(f))
check("L2: message lists the allowed folders", any("references" in x["message"] for x in f if x["rule"] == "L2"))
check("every spec folder is accepted", L.ALLOWED == (
    "references", "resources", "templates", "examples", "steps", "scripts", "assets"))

# --- L3 empty dirs -----------------------------------------------------------
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM}, dirs=("examples",))
    f = L.lint_skill(sk)
check("L3: an empty spec folder is flagged", rules(f) == ["L3"])
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM + "references/a.md\n", "references/a.md": "x"},
              dirs=("references/nested-empty",))
    f = L.lint_skill(sk)
check("L3: a nested empty dir is flagged", rules(f) == ["L3"])

# --- L4 reachability ---------------------------------------------------------
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM + "Read references/a.md.\n",
                         "references/a.md": "x", "references/orphan.md": "nobody points here"})
    f = L.lint_skill(sk)
check("L4: a file nothing points to is flagged", rules(f) == ["L4"])
check("L4: the finding names the orphan file", any(x["path"].endswith("orphan.md") for x in f))
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM, "references/island-a.md": "see `island-b.md`",
                         "references/island-b.md": "see `island-a.md`"})
    f = L.lint_skill(sk)
check("L4: files that only point at each other are NOT reachable", rules(f) == ["L4", "L4"])
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM + "templates/out.md\n", "templates/out.md": "x"})
    f = L.lint_skill(sk)
check("L4: a pointed-to file is reachable", f == [])

# --- L5 paths ----------------------------------------------------------------
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM + "See skills/other-skill/SKILL.md.\n"})
    f = L.lint_skill(sk)
check("L5: a repo-rooted path to another skill is flagged", rules(f) == ["L5"])
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM + "Run ${CLAUDE_PLUGIN_ROOT}/skills/fx/scripts/a.sh\n"})
    f = L.lint_skill(sk)
check("L5: CLAUDE_PLUGIN_ROOT addressing skills/ is flagged", "L5" in rules(f))
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM + "Load /opt/plugins/sdlc/skills/fx/references/a.md\n"})
    f = L.lint_skill(sk)
check("L5: an absolute path into a skills/ tree is flagged", "L5" in rules(f))
with tempfile.TemporaryDirectory() as td:
    sk = make(Path(td), {"SKILL.md": FM +
        "Trace shows /home/ci-runner/build/src/main.go:42.\n"
        "COPY . /app\n"
        'Run "${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" retrieve.py\n'})
    f = L.lint_skill(sk)
check("L5: example absolute paths and plugin-root repo scripts are NOT flagged", f == [])

# --- tree-level API, purity, live smoke --------------------------------------
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    make(root, {"SKILL.md": FM, "NOTES.md": "x"})
    res = L.lint(root / "skills")
check("lint() totals count findings per rule", res["totals"]["L1"] == 1 and res["totals"]["findings"] == 1)
check("lint() counts clean skills", res["totals"]["skills"] == 1 and res["totals"]["skills_clean"] == 0)

before = subprocess.run(["git", "-C", str(REPO_ROOT), "status", "--porcelain"],
                        capture_output=True, text=True).stdout
live = L.lint()
after = subprocess.run(["git", "-C", str(REPO_ROOT), "status", "--porcelain"],
                       capture_output=True, text=True).stdout
check("linting the live tree writes nothing", before == after)
check("live tree: every skill directory is linted", live["totals"]["skills"] == len(
    [p for p in (REPO_ROOT / "skills").iterdir() if p.is_dir()]))
rc = subprocess.run([sys.executable, str(MODULE_PATH), "--summary"], capture_output=True, text=True)
check("CLI exits 1 when findings exist, 0 when clean",
      rc.returncode == (1 if live["totals"]["findings"] else 0))
check("CLI --summary prints the totals block", "lint-skill-layout summary:" in rc.stdout)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
