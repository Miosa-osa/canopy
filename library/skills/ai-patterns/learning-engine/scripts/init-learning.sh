#!/bin/bash
# Initialize the learning storage structure

LEARNING_DIR="$HOME/.claude/learning"

echo "Initializing learning storage..."

# Create directories
mkdir -p "$LEARNING_DIR/patterns/frontend"
mkdir -p "$LEARNING_DIR/patterns/backend"
mkdir -p "$LEARNING_DIR/patterns/database"
mkdir -p "$LEARNING_DIR/patterns/devops"
mkdir -p "$LEARNING_DIR/patterns/security"
mkdir -p "$LEARNING_DIR/patterns/general"
mkdir -p "$LEARNING_DIR/solutions/bugs"
mkdir -p "$LEARNING_DIR/solutions/features"
mkdir -p "$LEARNING_DIR/solutions/performance"
mkdir -p "$LEARNING_DIR/solutions/security"
mkdir -p "$LEARNING_DIR/solutions/general"
mkdir -p "$LEARNING_DIR/gaps"
mkdir -p "$LEARNING_DIR/metrics"
mkdir -p "$LEARNING_DIR/events"

# Initialize index files
echo '{"version":"1.0.0","items":[],"stats":{"total":0}}' > "$LEARNING_DIR/patterns/index.json"
echo '{"version":"1.0.0","items":[],"stats":{"total":0}}' > "$LEARNING_DIR/solutions/index.json"
echo '{"version":"1.0.0","detected_gaps":[],"resolved_gaps":[],"pending_agents":[]}' > "$LEARNING_DIR/gaps/index.json"
echo '{"version":"1.0.0","sessions":0,"tasks_completed":0,"patterns_used":0,"agents_created":0,"history":[]}' > "$LEARNING_DIR/metrics/index.json"

echo "Learning storage initialized at $LEARNING_DIR"
echo ""
echo "Structure:"
echo "  patterns/   - Reusable code patterns by domain"
echo "  solutions/  - Bug fixes and problem solutions"
echo "  gaps/       - Detected capability gaps"
echo "  metrics/    - Usage statistics"
echo "  events/     - Session events"
