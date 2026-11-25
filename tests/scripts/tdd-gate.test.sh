#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

# No test file exists -> deny
smoke_test_script "tdd-gate" \
  '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/x.go"}}' "deny" "No test file found"

# Test file itself being written -> allow (it IS the test)
smoke_test_script "tdd-gate" \
  '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/x_test.go"}}' "allow"

# Test file exists first -> implementation write allowed
touch "$SCRATCH_DIR/y_test.go"
smoke_test_script "tdd-gate" \
  '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/y.go"}}' "allow"

# Non-Go/TS file -> not in scope, allow
smoke_test_script "tdd-gate" '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/README.md"}}' "allow"

# --- Edit (#1288): editing an implementation file is a change too
smoke_test_script "tdd-gate" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$SCRATCH_DIR"'/z.go","old_string":"a","new_string":"b"}}' "deny" "No test file found"
smoke_test_script "tdd-gate" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$SCRATCH_DIR"'/y.go","old_string":"a","new_string":"b"}}' "allow"

# --- L1/L2 (D048): accepted layouts, narrow exemptions, Python coverage
P="$SCRATCH_DIR/svc"
mkdir -p "$P"; touch "$P/go.mod" "$P/package.json" "$P/pyproject.toml"

have() { mkdir -p "$(dirname "$P/$1")"; touch "$P/$1"; }
gate() {  # gate <allow|deny> <path under $P> [content]
  local json
  json="$(python3 -c '
import json, sys
ti = {"file_path": sys.argv[1]}
if len(sys.argv) > 2: ti["content"] = sys.argv[2]
print(json.dumps({"tool_name": "Write", "tool_input": ti}))' "$P/$2" "${@:3}")"
  smoke_test_script "tdd-gate" "$json" "$1" || echo "  (case: $1 $2)"
}

# plain implementation files with no test are still denied, in every language
gate deny internal/domain/order.go
gate deny src/domain/order.ts
gate deny src/components/Card.tsx
gate deny src/shop/domain/order.py

# Go same-name variants
have internal/postgres/repo_integration_test.go
gate allow internal/postgres/repo.go
have internal/domain/user_role_test.go          # belongs to user_role.go only
gate deny internal/domain/user.go

# TypeScript variants and __tests__
have src/a/Panel.a11y.test.tsx;        gate allow src/a/Panel.tsx
have src/b/Panel.spec.tsx;             gate allow src/b/Panel.tsx
have src/c/__tests__/Panel.test.tsx;   gate allow src/c/Panel.tsx
have src/d/__tests__/Panel.a11y.spec.tsx; gate allow src/d/Panel.tsx
have src/e/useThing.test.tsx;          gate allow src/e/useThing.ts
have src/f/Other.test.tsx;             gate deny src/f/Panel.tsx

# Python test files and mirrored layouts
gate allow tests/unit/domain/test_order.py
gate allow src/shop/domain/price_test.py
have src/shop/a/test_alpha.py;                gate allow src/shop/a/alpha.py
have tests/domain/test_beta.py;               gate allow src/shop/domain/beta.py
have tests/unit/domain/test_gamma.py;         gate allow src/shop/domain/gamma.py
have tests/integration/shop/adapters/test_delta_integration.py; gate allow src/shop/adapters/delta.py
have tests/unit/other/test_epsilon.py;        gate deny src/shop/domain/epsilon.py
gate deny src/shop/domain/zeta.py

# test-support folders
for f in internal/test/builders/asset.go internal/test/fakes/repo.go internal/test/golden.go \
         internal/test/bdd/steps_asset.go tests/e2e/seed.go test/render.tsx test/setup.ts \
         src/test/setup.ts src/x/__mocks__/api.ts src/x/__tests__/helpers.tsx \
         internal/x/testdata/sample.go mocks/publisher_mock.go tests/fakes.py tests/e2e/tracing.py; do
  gate allow "$f"
done
# ... which do not reach same-named folders inside product code
gate deny src/shop/tests/scoring.py
gate deny src/features/test/Runner.tsx
gate deny internal/domain/test/rules.go
gate deny internal/testing/rules.go
gate deny mocks/pricing.go
gate deny internal/mocks_x/a_mock.go
gate deny tests/../src/shop/domain/sneaky.py     # path is normalised first

# configuration, test setup, type declarations
for f in vite.config.ts apps/shell/vite.config.ts playwright.config.ts vitest.workspace.ts \
         src/setupTests.ts src/vite-env.d.ts src/api/generated/schema.d.ts setup.py noxfile.py \
         conftest.py src/shop/tests/conftest.py load/locustfile.py; do
  gate allow "$f"
done
gate deny src/pricing.config.ts
gate deny pricing.config.ts
gate deny src/vite.config.ts
gate deny src/api/types.ts
gate deny src/shop/conftest.py
gate deny src/shop/settings.py
gate deny src/shop/setup.py

# migrations: by file-name shape inside migrations/ or alembic/
for f in migrations/versions/ab12_add_asset.py migrations/env.py alembic/versions/cd34_x.py \
         migrations/0001_initial.py internal/postgres/migrations/embed.go migrations/00002_add.go; do
  gate allow "$f"
done
gate deny src/shop/migrations/planner.py
gate deny internal/migrations/planner.go
gate deny src/shop/env.py

# entry, index and __init__ files: exempt only while thin
gate allow src/index.ts $'export * from "./a";\nexport { B, C as D } from "./b";\nimport "./styles.css";\nexport type { E } from "./e";\n'
gate deny  src/index.ts $'export * from "./a";\nexport const total = (a: number) => a * 2;\n'
gate deny  src/features/x/index.ts $'export function price() { return 1; }\n'
gate deny  src/features/x/index.ts
gate allow src/main.ts $'import("./bootstrap");\n'
gate allow src/main.tsx $'import ReactDOM from "react-dom/client";\nimport { App } from "./App";\nconst root = ReactDOM.createRoot(document.getElementById("root")!);\nroot.render(<App />);\n'
gate deny  src/main.tsx $'function discount(n: number) { return n * 0.9; }\ndiscount(1);\n'
gate deny  src/bootstrap.tsx "$(for i in $(seq 1 41); do echo "const v$i = $i;"; done)"
gate deny  src/features/x/main.tsx $'const rate = (n: number) => n * 0.9;\n'

gate allow cmd/server/main.go $'package main\n\nimport "os"\n\nfunc main() {\n\tif err := run(); err != nil {\n\t\tos.Exit(1)\n\t}\n}\n\nfunc run() error { return nil }\n'
gate allow main.go $'package main\n\nfunc main() {}\n'
gate deny  cmd/server/main.go $'package main\n\nfunc main() {}\n\nfunc discount(n int) int { return n - 1 }\n'
gate deny  cmd/server/main.go $'package main\n\ntype pricer struct{}\n\nfunc main() {}\n'
gate deny  cmd/server/main.go $'package main\n\nvar discount = func(n int) int { return n - 1 }\n\nfunc main() {}\n'
gate deny  cmd/server/main.go $'package main\n\nvar (\n\tdiscount = func(n int) int { return n - 1 }\n)\n\nfunc main() {}\n'
gate deny  cmd/server/main.go "$(printf 'package main\n\nfunc main() {\n'; for i in $(seq 1 101); do echo "	println($i)"; done; echo '}')"
gate deny  internal/domain/main.go $'package main\n\nfunc main() {}\n'
gate deny  cmd/server/wiring.go $'package main\n'
gate deny  cmd/server/main.go

gate allow src/shop/__init__.py ""
gate allow src/shop/__init__.py $'"""Domain layer."""\nfrom .order import Order\n__all__ = ["Order"]\nVERSION = "1"\n'
gate deny  src/shop/__init__.py $'def price(n):\n    return n * 2\n'
gate deny  src/shop/__init__.py $'price = lambda n: n * 2\n'
gate deny  src/shop/__init__.py $'class Order:\n    pass\n'
gate allow src/shop/__main__.py $'from shop.app import main\n\nif __name__ == "__main__":\n    raise SystemExit(main())\n'
gate allow src/shop/main.py $'from shop.app import create_app\n\napp = create_app()\n'
gate deny  src/shop/main.py $'def price(n):\n    return n * 2\n'
gate deny  src/shop/main.py $'for n in range(3):\n    print(n)\n'

# an Edit is judged on the text it will produce, not the text on disk
mkdir -p "$P/pkg"; printf 'from .a import A\n' > "$P/pkg/__init__.py"
smoke_test_script "tdd-gate" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$P"'/pkg/__init__.py","old_string":"from .a import A","new_string":"from .a import B"}}' "allow"
smoke_test_script "tdd-gate" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$P"'/pkg/__init__.py","old_string":"from .a import A","new_string":"def f():\n    return 1"}}' "deny" "No test file found"

# relative paths resolve against the payload's cwd
smoke_test_script "tdd-gate" '{"cwd":"'"$P"'","tool_input":{"file_path":"src/a/Panel.tsx"}}' "allow"

# a payload too large for a command-line argument is still checked
BIG="$SCRATCH_DIR/big.json"
python3 -c 'import json,sys; print(json.dumps({"tool_input":{"file_path":sys.argv[1],"content":"x = 1\n"*100000}}))' "$P/src/shop/big.py" > "$BIG"
if "$REPO_ROOT/scripts/tdd-gate.sh" < "$BIG" | grep -q '"permissionDecision": "deny"'; then
  _pass "scripts/tdd-gate (large payload denied)"
else
  _fail "scripts/tdd-gate" "large payload was not denied"
fi

smoke_test_summary
