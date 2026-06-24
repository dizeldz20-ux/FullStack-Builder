#!/usr/bin/env bash
# scaffold-python.sh — Build-product v1.3.0
# Bootstrap a new Python 3.12 + FastAPI project in 30 seconds.
# Borrowed from a peer agent's super-builder/scaffold-python.sh pattern.
#
# Usage: ./scaffold-python.sh [project-name]
# Default: scaffold in current directory
# After: run `uv venv && source .venv/bin/activate && uv pip install -e .`,
#        then `uvicorn src.main:app --reload`, then `curl http://localhost:8000/health`

set -euo pipefail

PROJECT_NAME="${1:-$(basename "$PWD")}"
PORT="${PORT:-8000}"

echo "🐍 Scaffolding Python 3.12 + FastAPI project: $PROJECT_NAME"
echo ""

# 1. pyproject.toml
cat > pyproject.toml <<EOF
[project]
name = "$PROJECT_NAME"
version = "0.1.0"
description = "$PROJECT_NAME — built with build-product"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115",
    "uvicorn[standard]>=0.32",
    "pydantic>=2.9",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3",
    "ruff>=0.7",
    "httpx>=0.27",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src"]
EOF
echo "✅ pyproject.toml"

# 2. src/main.py
mkdir -p src tests
cat > src/main.py <<EOF
"""$PROJECT_NAME — built with build-product."""
from datetime import datetime, timezone

from fastapi import FastAPI

app = FastAPI(title="$PROJECT_NAME", version="0.1.0")


@app.get("/health")
def health() -> dict:
    """Liveness + version (REQUIRED for build-product deployment checklist)."""
    return {
        "ok": True,
        "service": "$PROJECT_NAME",
        "version": "0.1.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/")
def root() -> dict:
    return {"message": "Hello from build-product"}
EOF
cat > src/__init__.py <<'EOF'
EOF
echo "✅ src/main.py"

# 3. tests/test_health.py
cat > tests/test_health.py <<'EOF'
"""Smoke test for the /health endpoint (required by build-product)."""
from fastapi.testclient import TestClient

from src.main import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["ok"] is True
    assert "version" in body
EOF
cat > tests/__init__.py <<'EOF'
EOF
echo "✅ tests/test_health.py"

# 4. .env.example
cat > .env.example <<EOF
# Server
PORT=$PORT

# Add your env vars below. NEVER commit real values.
# OPENAI_API_KEY=
# SUPABASE_URL=
# SUPABASE_SERVICE_ROLE_KEY=
EOF
echo "✅ .env.example"

# 5. .gitignore
cat > .gitignore <<'EOF'
# Virtual env
.venv/
venv/
env/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so

# Distribution
dist/
build/
*.egg-info/

# Environment
.env
.env.local
.env.*.local

# Tests
.pytest_cache/
.coverage
htmlcov/

# IDE
.vscode/
.idea/
*.swp
.DS_Store

# OS
Thumbs.db
EOF
echo "✅ .gitignore"

# 6. README.md
cat > README.md <<EOF
# $PROJECT_NAME

> One-line description: what this does.

## Quick start (3 commands)

\`\`\`bash
uv venv
source .venv/bin/activate
uv pip install -e ".[dev]"
uvicorn src.main:app --reload
\`\`\`

Then open http://localhost:$PORT/health — should return \`{"ok": true}\`.

## API

| Method | Path | Purpose |
|--------|------|---------|
| GET    | /    | Root |
| GET    | /health | Liveness + version |

## Reinstall from scratch

\`\`\`bash
rm -rf .venv
uv venv && source .venv/bin/activate
uv pip install -e ".[dev]"
uvicorn src.main:app --reload
\`\`\`

## Tests + lint

\`\`\`bash
pytest          # run all tests
ruff check .    # lint
ruff format .   # format
\`\`\`

---

_Built with [build-product](https://github.com/<your-github-username>/FullStack-Builder) v1.3.0_
EOF
echo "✅ README.md"

# 7. ruff config
cat > ruff.toml <<'EOF'
target-version = "py312"
line-length = 100

[lint]
select = ["E", "F", "I", "B", "UP"]
EOF
echo "✅ ruff.toml"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Project $PROJECT_NAME scaffolded."
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_NAME (if you used ./scaffold-python.sh from outside)"
echo "  2. uv venv && source .venv/bin/activate"
echo "  3. uv pip install -e '.[dev]'"
echo "  4. uvicorn src.main:app --reload"
echo "  5. curl http://localhost:$PORT/health"
echo ""
echo "Then come back to /build-product feature to add functionality."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
