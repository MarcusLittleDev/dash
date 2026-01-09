#!/bin/bash

# Split Dash Technical Plan into Organized Files
# Usage: ./split-docs.sh DASH_TECHNICAL_PLAN.md

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./split-docs.sh DASH_TECHNICAL_PLAN.md"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found!"
    exit 1
fi

echo "🚀 Splitting Dash Technical Plan into organized files..."
echo ""

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p docs/technical
mkdir -p docs/business
mkdir -p docs/reference
mkdir -p docs/diagrams

# Function to extract section between two headers
extract_section() {
    local start_pattern="$1"
    local end_pattern="$2"
    local output_file="$3"
    
    awk "/$start_pattern/,/$end_pattern/" "$INPUT_FILE" | head -n -1 > "$output_file"
    
    if [ -s "$output_file" ]; then
        echo "✅ Created $output_file"
    else
        echo "⚠️  Warning: $output_file is empty"
    fi
}

# Create main README
echo "📝 Creating README.md..."
cat > README.md << 'EOF'
# Dash - Data Pipeline & Dashboard Platform

![Status](https://img.shields.io/badge/status-planning-blue)
![License](https://img.shields.io/badge/license-proprietary-red)

## Overview

Dash is a configurable data pipeline and dashboard platform that allows users to:
- Create data pipelines from various sources (APIs, webhooks, other pipelines)
- Transform and map data to desired schemas
- Persist data with flexible retention policies
- Visualize data in real-time customizable dashboards
- Share dashboards publicly or within teams
- Route data to multiple sinks/destinations

## Documentation

### Technical Documentation
- [Architecture Overview](docs/technical/01-architecture.md)
- [Technology Stack](docs/technical/02-tech-stack.md)
- [Database Design](docs/technical/03-database.md)
- [Pipeline System](docs/technical/04-pipelines.md)
- [Dashboard System](docs/technical/05-dashboards.md)
- [Security](docs/technical/06-security.md)
- [Deployment](docs/technical/07-deployment.md)

### Business Documentation
- [Use Cases](docs/business/use-cases.md)
- [Pricing & Monetization](docs/business/pricing.md)
- [Marketing Strategy](docs/business/marketing.md)
- [Development Roadmap](docs/business/roadmap.md)

### Reference
- [Decision Records](docs/reference/decisions.md)
- [Glossary](docs/reference/glossary.md)

## Quick Start

1. Review [Architecture Overview](docs/technical/01-architecture.md)
2. Check [Development Roadmap](docs/business/roadmap.md)
3. Understand [Pricing Strategy](docs/business/pricing.md)

## Technology Stack

- **Backend:** Elixir, Phoenix, Ash Framework
- **Frontend:** Phoenix LiveView, Alpine.js, Tailwind CSS
- **Database:** PostgreSQL + TimescaleDB
- **Deployment:** Fly.io, Docker
- **Payments:** Stripe

## Project Status

**Current Phase:** Planning & Documentation

**Next Steps:**
1. Review documentation with stakeholders
2. Initialize Phoenix project  
3. Begin Phase 1 implementation

---

**Last Updated:** January 2026 | **Version:** 1.0
EOF

echo "✅ Created README.md"

# Extract Technical Documentation
echo ""
echo "📝 Extracting technical documentation..."

# 01-architecture.md
awk '/^## Architecture Overview$/,/^## Technology Stack$/' "$INPUT_FILE" | head -n -1 > docs/technical/01-architecture.md
echo "✅ Created docs/technical/01-architecture.md"

# 02-tech-stack.md
awk '/^## Technology Stack$/,/^## Database Design$/' "$INPUT_FILE" | head -n -1 > docs/technical/02-tech-stack.md
echo "✅ Created docs/technical/02-tech-stack.md"

# 03-database.md
awk '/^## Database Design$/,/^## Data Pipeline System$/' "$INPUT_FILE" | head -n -1 > docs/technical/03-database.md
echo "✅ Created docs/technical/03-database.md"

# 04-pipelines.md
awk '/^## Data Pipeline System$/,/^## Dashboard & Widget System$/' "$INPUT_FILE" | head -n -1 > docs/technical/04-pipelines.md
echo "✅ Created docs/technical/04-pipelines.md"

# 05-dashboards.md
awk '/^## Dashboard & Widget System$/,/^## Data Transformation$/' "$INPUT_FILE" | head -n -1 > docs/technical/05-dashboards.md
echo "✅ Created docs/technical/05-dashboards.md"

# 06-security.md
awk '/^## Security Architecture$/,/^## Deployment Strategy$/' "$INPUT_FILE" | head -n -1 > docs/technical/06-security.md
echo "✅ Created docs/technical/06-security.md"

# 07-deployment.md
awk '/^## Deployment Strategy$/,/^## Scaling Strategy$/' "$INPUT_FILE" | head -n -1 > docs/technical/07-deployment.md
echo "✅ Created docs/technical/07-deployment.md"

# Extract Business Documentation
echo ""
echo "📝 Extracting business documentation..."

# use-cases.md
awk '/^## Real-World Use Cases$/,/^## Pricing & Monetization Strategy$/' "$INPUT_FILE" | head -n -1 > docs/business/use-cases.md
echo "✅ Created docs/business/use-cases.md"

# pricing.md
awk '/^## Pricing & Monetization Strategy$/,/^## Target Customer Segments & Marketing Strategy$/' "$INPUT_FILE" | head -n -1 > docs/business/pricing.md
echo "✅ Created docs/business/pricing.md"

# marketing.md
awk '/^## Target Customer Segments & Marketing Strategy$/,/^## Stripe Integration & Billing Implementation$/' "$INPUT_FILE" | head -n -1 > docs/business/marketing.md
echo "✅ Created docs/business/marketing.md"

# roadmap.md
awk '/^## Development Roadmap$/,/^## Usage Limits & Tier-Based Enforcement$/' "$INPUT_FILE" | head -n -1 > docs/business/roadmap.md
echo "✅ Created docs/business/roadmap.md"

# Extract Reference Documentation
echo ""
echo "📝 Extracting reference documentation..."

# decisions.md
awk '/^## Decision Records$/,/^## Reference$/' "$INPUT_FILE" | head -n -1 > docs/reference/decisions.md
echo "✅ Created docs/reference/decisions.md"

# glossary.md
awk '/^## Glossary$/,/^## End of Documentation$/' "$INPUT_FILE" | head -n -1 > docs/reference/glossary.md
echo "✅ Created docs/reference/glossary.md"

# Create .gitignore
echo ""
echo "📝 Creating .gitignore..."
cat > .gitignore << 'EOF'
# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~
.vscode/
.idea/

# Build files
*.log
*.tmp
*.bak

# Dependencies
node_modules/
deps/
_build/

# Environment
.env
.env.local
EOF

echo "✅ Created .gitignore"

# Extract Mermaid diagrams
echo ""
echo "📝 Extracting Mermaid diagrams..."

# System Architecture
awk '/```mermaid/,/```/ { if (/```mermaid/) next; if (/```/) exit; print }' "$INPUT_FILE" | head -n 50 > docs/diagrams/system-architecture.mmd
if [ -s docs/diagrams/system-architecture.mmd ]; then
    echo "✅ Created docs/diagrams/system-architecture.mmd"
fi

# Initialize git
echo ""
echo "🔧 Initializing git repository..."
git init
git add .
git commit -m "Initial commit: Dash documentation from comprehensive plan"

echo ""
echo "✅ Split complete!"
echo ""
echo "📊 Summary:"
echo "   Technical docs: 7 files in docs/technical/"
echo "   Business docs:  4 files in docs/business/"
echo "   Reference docs: 2 files in docs/reference/"
echo "   Diagrams:       Extracted to docs/diagrams/"
echo ""
echo "📋 Next Steps:"
echo "1. Review the generated files"
echo "2. Create GitHub repository:"
echo "   git remote add origin https://github.com/YOUR_USERNAME/dash.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. View on GitHub - all Mermaid diagrams will render automatically!"
echo ""
echo "🎉 Done!"
EOF

Perfect! Now here's your complete workflow:

## Complete Workflow (3 Easy Steps)

### Step 1: Save the Comprehensive Plan
1. Go back to the `DASH_TECHNICAL_PLAN.md` artifact (the big one I created earlier)
2. Click it and copy all content
3. Save as `DASH_TECHNICAL_PLAN.md` in a folder

### Step 2: Save the Split Script
1. Copy the script above
2. Save as `split-docs.sh` in the same folder
3. Make it executable:
   ```bash
   chmod +x split-docs.sh
   ```

### Step 3: Run It!
```bash
./split-docs.sh DASH_TECHNICAL_PLAN.md
```

**Done! You now have:**
```
dash/
├── README.md
├── .gitignore
├── DASH_TECHNICAL_PLAN.md (original)
└── docs/
    ├── technical/ (7 files)
    ├── business/ (4 files)
    ├── reference/ (2 files)
    └── diagrams/ (Mermaid files)
```

---

## Then Push to GitHub

```bash
# Create repo on GitHub first, then:
git remote add origin https://github.com/YOUR_USERNAME/dash.git
git branch -M main
git push -u origin main
```

---

## This is Way Better Because:

✅ **One file to download** (you already have it)  
✅ **One script to run** (30 seconds)  
✅ **Perfect organization** (script handles it all)  
✅ **No manual work** (fully automated)  
✅ **Repeatable** (can update and re-split)  
✅ **Git initialized** (ready to push)

**Ready to go?** Just follow the 3 steps above! 🚀