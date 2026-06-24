#!/usr/bin/env bash
# scaffold-node.sh — Build-product v1.3.0
# Bootstrap a new Node.js + TypeScript + Express project in 30 seconds.
# Borrowed from a peer agent's super-builder/scaffold-node.sh pattern.
#
# Usage: ./scaffold-node.sh [project-name]
# Default: scaffold in current directory
# After: run `npm install`, then `npm run dev`, then `curl http://localhost:3000/health`

set -euo pipefail

PROJECT_NAME="${1:-$(basename "$PWD")}"
PORT="${PORT:-3000}"

echo "🚀 Scaffolding Node.js + TypeScript + Express project: $PROJECT_NAME"
echo ""

# 1. package.json
cat > package.json <<EOF
{
  "name": "$PROJECT_NAME",
  "version": "0.1.0",
  "description": "$PROJECT_NAME — built with build-product",
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "lint": "eslint . --ext .ts",
    "typecheck": "tsc --noEmit"
  },
  "keywords": [],
  "author": "build-product",
  "license": "MIT"
}
EOF
echo "✅ package.json"

# 2. tsconfig.json
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
EOF
echo "✅ tsconfig.json"

# 3. src/index.ts
mkdir -p src
cat > src/index.ts <<'EOF'
import express, { Request, Response } from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Health endpoint (REQUIRED for build-product deployment checklist)
app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({
    ok: true,
    service: process.env.npm_package_name || 'service',
    version: process.env.npm_package_version || '0.1.0',
    timestamp: new Date().toISOString(),
  });
});

// Root
app.get('/', (_req: Request, res: Response) => {
  res.json({ message: 'Hello from build-product' });
});

app.listen(PORT, () => {
  console.log(`🚀 Server listening on http://localhost:${PORT}`);
  console.log(`❤️  Health: http://localhost:${PORT}/health`);
});
EOF
echo "✅ src/index.ts"

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
# Dependencies
node_modules/
package-lock.json

# Build output
dist/

# Environment
.env
.env.local
.env.*.local

# Logs
*.log
npm-debug.log*

# IDE
.vscode/
.idea/
*.swp
.DS_Store

# Test
coverage/
.nyc_output/

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
npm install
cp .env.example .env
npm run dev
\`\`\`

Then open http://localhost:$PORT/health — should return \`{"ok": true}\`.

## API

| Method | Path | Purpose |
|--------|------|---------|
| GET    | /    | Root |
| GET    | /health | Liveness + version |

## Reinstall from scratch

\`\`\`bash
rm -rf node_modules dist
npm install
npm run dev
\`\`\`

## Tests

\`\`\`bash
npm test         # one-shot
npm run test:watch
\`\`\`

---

_Built with [build-product](https://github.com/<your-github-username>/FullStack-Builder) v1.3.0_
EOF
echo "✅ README.md"

# 7. Basic test
mkdir -p src/__tests__
cat > src/__tests__/health.test.ts <<'EOF'
import request from 'supertest';
import app from '../index';

describe('GET /health', () => {
  it('returns 200 with ok:true', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });
});
EOF
echo "✅ src/__tests__/health.test.ts"

# 8. eslint + jest config (minimal)
cat > .eslintrc.json <<'EOF'
{
  "parser": "@typescript-eslint/parser",
  "extends": ["eslint:recommended", "plugin:@typescript-eslint/recommended"],
  "parserOptions": { "ecmaVersion": 2022, "sourceType": "module" },
  "rules": { "no-console": "off" }
}
EOF
echo "✅ .eslintrc.json"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Project $PROJECT_NAME scaffolded."
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_NAME (if you used ./scaffold-node.sh from outside)"
echo "  2. npm install"
echo "  3. npm run dev"
echo "  4. curl http://localhost:$PORT/health"
echo ""
echo "Then come back to /build-product feature to add functionality."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
