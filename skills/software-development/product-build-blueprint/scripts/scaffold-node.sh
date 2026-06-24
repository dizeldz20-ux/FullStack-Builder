#!/bin/bash
# Scaffold פרויקט Node.js חדש
# שימוש: bash scripts/scaffold-node.sh <project-name>
#
# Creates a bare-bones Node.js project with:
# - src/index.js (Express-style /health endpoint)
# - package.json with npm start
# - .env.example
# - README.md with quick start
# - .gitignore (node_modules, .env)

set -euo pipefail

NAME="${1:-my-project}"
DIR="$NAME"

if [ -d "$DIR" ]; then
  echo "❌ תיקייה $DIR כבר קיימת"
  exit 1
fi

mkdir -p "$DIR/src"
cd "$DIR"

# package.json
cat > package.json << EOF
{
  "name": "$NAME",
  "version": "1.0.0",
  "description": "",
  "main": "src/index.js",
  "type": "module",
  "scripts": {
    "start": "node src/index.js",
    "dev": "node --watch src/index.js"
  },
  "dependencies": {}
}
EOF

# index.js בסיסי
cat > src/index.js << 'EOF'
import express from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
EOF

# .env.example
cat > .env.example << 'EOF'
PORT=3000
# Add your env vars here
EOF

# .gitignore
cat > .gitignore << 'EOF'
node_modules/
.env
.DS_Store
*.log
EOF

# README
cat > README.md << EOF
# $NAME

Quick description.

## Quick Start

\`\`\`bash
npm install
cp .env.example .env
npm start
\`\`\`

Server runs on http://localhost:3000

## API

- \`GET /health\` — health check
EOF

echo "✅ Created: $DIR/"
echo "   cd $DIR && npm install && npm start"
