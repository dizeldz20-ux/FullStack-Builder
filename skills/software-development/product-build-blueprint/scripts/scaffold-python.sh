#!/bin/bash
# Scaffold פרויקט Python חדש
# שימוש: bash scripts/scaffold-python.sh <project-name>
#
# Creates a bare-bones Python project with:
# - src/main.py (Flask-style /health endpoint)
# - requirements.txt
# - .env.example
# - README.md with quick start
# - .gitignore

set -euo pipefail

NAME="${1:-my-project}"
DIR="$NAME"

if [ -d "$DIR" ]; then
  echo "❌ תיקייה $DIR כבר קיימת"
  exit 1
fi

mkdir -p "$DIR/src"
cd "$DIR"

# requirements.txt
cat > requirements.txt << 'EOF'
flask>=3.0.0
python-dotenv>=1.0.0
EOF

# src/main.py
cat > src/main.py << 'EOF'
from flask import Flask, jsonify
from datetime import datetime
import os

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'time': datetime.now().isoformat()})

if __name__ == '__main__':
    port = int(os.getenv('PORT', 3000))
    app.run(host='0.0.0.0', port=port, debug=True)
EOF

# .env.example
cat > .env.example << 'EOF'
PORT=3000
# Add your env vars here
EOF

# .gitignore
cat > .gitignore << 'EOF'
.venv/
__pycache__/
*.pyc
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
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python src/main.py
\`\`\`

Server runs on http://localhost:3000

## API

- \`GET /health\` — health check
EOF

echo "✅ Created: $DIR/"
echo "   cd $DIR && python3 -m venv .venv && source .venv/bin/activate"
echo "   pip install -r requirements.txt && python src/main.py"
