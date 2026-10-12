#!/usr/bin/env python3
"""product-state.py — the single writer of a product's phase and approvals.

A product's state lives in its manifest, artifacts/<product>/_manifest.json
(proposal 13, #1251/#1253). The post-artifact-created hook records artifact
entries; this script records everything a human decides: which artifacts are
approved, and when a phase is complete. Phase commands call it through
"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py"; the pre-phase-advance hook
reads what it writes.

  init <slug> --name "<name>" [--problem "<problem statement>"]
  approve <artifact path> [<artifact path> ...]
  complete <phase> [--override "<reason>"]
  status
  plan [<phase>]      what this phase produces at the product's scale profile

What a phase requires comes from
skills/artifact-manifest/resources/phase-requirements.json. Output is JSON on
stdout. Exit codes: 0 done, 1 refused (incomplete phase, unknown artifact,
product already exists), 2 usage or environment error.
"""
from __future__ import annotations

import argparse
import datetime
import fnmatch
import json
import os
import re
import subprocess
import sys
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
REQUIREMENTS = PLUGIN_ROOT / "skills" / "artifact-manifest" / "resources" / "phase-requirements.json"
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
DEFAULT_PROFILE = "enterprise"


def fail(code: int, message: str, **extra) -> None:
    print(json.dumps({"ok": False, "error": message, **extra}, indent=2))
    sys.exit(code)


def repo_root() -> Path:
    env = os.environ.get("SDLC_PRODUCT_ROOT")
    if env:
        return Path(env).resolve()
    try:
        out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True)
        return Path(out.stdout.strip())
    except (OSError, subprocess.CalledProcessError):
        return Path.cwd()


def requirements() -> dict:
    return json.loads(REQUIREMENTS.read_text())


def today() -> str:
    return datetime.date.today().isoformat()


def manifests(root: Path) -> list[Path]:
    return sorted((root / "artifacts").glob("*/_manifest.json"))


def find_manifest(root: Path, slug: str | None) -> Path:
    if slug:
        path = root / "artifacts" / slug / "_manifest.json"
        if not path.exists():
            fail(1, f"No product '{slug}' here (expected {path.relative_to(root)}). Run /sdlc-start first.")
        return path
    found = manifests(root)
    if not found:
        fail(1, "No product has been started in this repo. Run /sdlc-start first.")
    if len(found) > 1:
        fail(2, "More than one product in this repo; pass --product <slug>.",
             products=[p.parent.name for p in found])
    return found[0]


def load(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        fail(2, f"Cannot read {path}: {exc}")


def save(path: Path, manifest: dict) -> None:
    manifest.setdefault("_meta", {})["last_updated"] = today()
    manifest["_meta"]["updated_by"] = "product-state.py"
    path.write_text(json.dumps(manifest, indent=2) + "\n")


def profile_of(root: Path) -> str:
    """The product's scale profile (proposal 14); enterprise when unset (today's full set)."""
    config = root / "sdlc-config.json"
    if config.exists():
        try:
            profile = json.loads(config.read_text()).get("scale_profile") or DEFAULT_PROFILE
        except ValueError:
            return DEFAULT_PROFILE
        if profile not in requirements()["_meta"]["profiles"]:
            fail(2, f"sdlc-config.json scale_profile '{profile}' is not one of "
                    f"{', '.join(requirements()['_meta']['profiles'])}.")
        return profile
    return DEFAULT_PROFILE


def phase_plan(phase: str, profile: str) -> dict:
    """What `phase` produces at `profile`: required, optional (with when), skipped."""
    req = requirements()
    plan = {"phase": phase, "scale_profile": profile, "required": [], "optional": [], "skipped": []}
    for e in req["phases"].get(phase, []):
        level = e["profiles"].get(profile, "required")
        if level == "skip":
            plan["skipped"].append(e["artifact"])
            continue
        item = {"artifact": e["artifact"], "path": e["paths"][0], "agent": e["agent"]}
        if e.get("note"):
            item["note"] = e["note"]
        plan["required" if level == "required" else "optional"].append(item)
    guide = req.get("guidance", {}).get(profile, {})
    plan["approval_mode"] = guide.get("approval_mode")
    plan["approval_mode_note"] = guide.get("approval_mode_note")
    if guide.get(phase):
        plan["guidance"] = guide[phase]
    return plan


def phase_check(manifest: dict, phase: str, profile: str) -> dict:
    """Which required artifacts of `phase` are missing or not yet approved."""
    reqs = requirements()["phases"].get(phase, [])
    entries = manifest.get("artifacts", [])
    prefix = f"artifacts/{manifest.get('product_slug', '')}/"
    missing, unapproved, approved = [], [], []
    for req in reqs:
        level = req["profiles"].get(profile, req["profiles"].get(DEFAULT_PROFILE))
        if level != "required":
            continue
        matches = [e for e in entries
                   if any(fnmatch.fnmatch(e.get("path", "")[len(prefix):], pat) for pat in req["paths"])]
        if not matches:
            missing.append({"artifact": req["artifact"], "expected_at": req["paths"], "agent": req["agent"]})
        elif not any(e.get("status") == "approved" for e in matches):
            unapproved.append({"artifact": req["artifact"], "paths": [e["path"] for e in matches]})
        else:
            approved.append(req["artifact"])
    return {"missing": missing, "unapproved": unapproved, "approved": approved}


def cmd_init(root: Path, args) -> None:
    if not SLUG.match(args.slug):
        fail(2, f"Product slug '{args.slug}' must be lowercase words joined by hyphens, e.g. lunch-tracker.")
    existing = manifests(root)
    if existing:
        fail(1, "A product already exists in this repo.", products=[p.parent.name for p in existing])
    path = root / "artifacts" / args.slug / "_manifest.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        "_meta": {
            "purpose": f"Registry of every artifact produced for product {args.name}: what exists, where, its status, what it traces to, and which phase the product is in.",
            "how_to_use": "Artifact entries are maintained by the post-artifact-created hook on every write. Approvals and phase completion are recorded only by scripts/product-state.py, after the user approves. Never edit by hand.",
            "last_updated": today(),
            "updated_by": "product-state.py",
        },
        "product": args.name,
        "product_slug": args.slug,
        "current_phase": "strategy",
        "phases": {"strategy": {"status": "in-progress"}},
        "artifacts": [],
    }
    if args.problem:
        manifest["problem_statement"] = args.problem
    save(path, manifest)
    print(json.dumps({"ok": True, "product": args.slug, "manifest": str(path.relative_to(root)),
                      "current_phase": "strategy"}, indent=2))


def cmd_approve(root: Path, args) -> None:
    path = find_manifest(root, args.product)
    manifest = load(path)
    done, unknown = [], []
    for raw in args.paths:
        p = Path(raw)
        rel = (p.resolve().relative_to(root) if p.is_absolute() else p).as_posix()
        if not rel.startswith("artifacts/"):
            rel = f"artifacts/{manifest['product_slug']}/{rel}"
        entry = next((e for e in manifest.get("artifacts", []) if e.get("path") == rel), None)
        if entry is None:
            unknown.append(rel)
            continue
        entry["status"] = "approved"
        entry["approved_on"] = today()
        done.append(rel)
    if done:
        save(path, manifest)
    if unknown:
        fail(1, "Not recorded in the manifest (write the artifact first; the hook registers it).",
             approved=done, unknown=unknown)
    print(json.dumps({"ok": True, "approved": done}, indent=2))


def cmd_complete(root: Path, args) -> None:
    order = requirements()["_meta"]["phase_order"]
    if args.phase not in order:
        fail(2, f"Unknown phase '{args.phase}'. Phases: {', '.join(order)}.")
    path = find_manifest(root, args.product)
    manifest = load(path)
    check = phase_check(manifest, args.phase, profile_of(root))
    if (check["missing"] or check["unapproved"]) and not args.override:
        fail(1, f"The {args.phase} phase can't be approved yet.", **check)
    phases = manifest.setdefault("phases", {})
    record = {"status": "approved", "approved_on": today()}
    if args.override:
        record["override"] = args.override
    phases[args.phase] = record
    i = order.index(args.phase)
    nxt = order[i + 1] if i + 1 < len(order) else None
    if nxt:
        manifest["current_phase"] = nxt
        phases.setdefault(nxt, {"status": "in-progress"})
    save(path, manifest)
    print(json.dumps({"ok": True, "approved_phase": args.phase, "current_phase": manifest.get("current_phase"),
                      "override": args.override or None}, indent=2))


def cmd_status(root: Path, args) -> None:
    found = [root / "artifacts" / args.product / "_manifest.json"] if args.product else manifests(root)
    if not found or not found[0].exists():
        print(json.dumps({"ok": True, "product": None,
                          "message": "No product has been started in this repo. Run /sdlc-start."}, indent=2))
        return
    if len(found) > 1:
        fail(2, "More than one product in this repo; pass --product <slug>.", products=[p.parent.name for p in found])
    manifest = load(found[0])
    current = manifest.get("current_phase", "strategy")
    entries = manifest.get("artifacts", [])
    counts = {}
    for e in entries:
        c = counts.setdefault(e.get("phase", "?"), {"approved": 0, "draft": 0, "superseded": 0})
        c[e.get("status", "draft")] = c.get(e.get("status", "draft"), 0) + 1
    print(json.dumps({
        "ok": True,
        "product": manifest.get("product"),
        "product_slug": manifest.get("product_slug"),
        "problem_statement": manifest.get("problem_statement"),
        "scale_profile": profile_of(root),
        "approval_mode": requirements().get("guidance", {}).get(profile_of(root), {}).get("approval_mode"),
        "current_phase": current,
        "phases": manifest.get("phases", {}),
        "artifact_counts_by_phase": counts,
        "current_phase_check": phase_check(manifest, current, profile_of(root)),
    }, indent=2))


def cmd_plan(root: Path, args) -> None:
    order = requirements()["_meta"]["phase_order"]
    phase = args.phase
    if phase is None:
        found = [root / "artifacts" / args.product / "_manifest.json"] if args.product else manifests(root)
        phase = load(found[0]).get("current_phase", "strategy") if found and found[0].exists() else "strategy"
    if phase not in order:
        fail(2, f"Unknown phase '{phase}'. Phases: {', '.join(order)}.")
    print(json.dumps({"ok": True, **phase_plan(phase, profile_of(root))}, indent=2))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Record a product's approvals and phase (the manifest's single state writer).")
    parser.add_argument("--product", help="product slug, if the repo has more than one")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("init")
    p.add_argument("slug")
    p.add_argument("--name", required=True)
    p.add_argument("--problem")
    p = sub.add_parser("approve")
    p.add_argument("paths", nargs="+")
    p = sub.add_parser("complete")
    p.add_argument("phase")
    p.add_argument("--override", help="approve despite missing items; the reason is recorded")
    sub.add_parser("status")
    p = sub.add_parser("plan")
    p.add_argument("phase", nargs="?")
    args = parser.parse_args(argv)
    root = repo_root()
    {"init": cmd_init, "approve": cmd_approve, "complete": cmd_complete, "status": cmd_status,
     "plan": cmd_plan}[args.cmd](root, args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
