#!/bin/bash
# Gather stacked PR context using Graphite (gt) CLI

set -e

# Check if gt is available
if ! command -v gt &> /dev/null; then
    echo "Graphite CLI (gt) not installed - skipping stack context"
    exit 0
fi

# Check if we're in a gt-enabled repo
if ! gt status >/dev/null 2>&1; then
    echo "Not a Graphite-tracked repository - skipping stack context"
    exit 0
fi

echo "=== GRAPHITE STACK STATUS ==="
gt status 2>/dev/null || echo "Could not get stack status"

echo ""
echo "=== STACK LOG ==="
gt log --stack 2>/dev/null || echo "Could not get stack log"

echo ""
echo "=== FULL STACK VIEW ==="
gt stack 2>/dev/null || echo "Could not get stack view"
