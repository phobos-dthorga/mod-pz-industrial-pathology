#!/bin/bash
# bump-version.sh — Update PIP version in all 2 locations.
# Usage: ./scripts/bump-version.sh 0.2.0

set -e

VERSION="$1"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.2.0"
    exit 1
fi

if ! echo "$VERSION" | grep -qP '^\d+\.\d+\.\d+$'; then
    echo "Error: Version must be in X.Y.Z format (got: $VERSION)"
    exit 1
fi

echo "Bumping PIP to $VERSION ..."

# 1. mod.info (root)
OLD=$(grep -oP 'modversion=\K[0-9]+\.[0-9]+\.[0-9]+' mod.info)
sed -i "s/modversion=[0-9]*\.[0-9]*\.[0-9]*/modversion=$VERSION/" mod.info
echo "  mod.info (root): $OLD -> $VERSION"

# 2. 42/mod.info
OLD=$(grep -oP 'modversion=\K[0-9]+\.[0-9]+\.[0-9]+' 42/mod.info)
sed -i "s/modversion=[0-9]*\.[0-9]*\.[0-9]*/modversion=$VERSION/" 42/mod.info
echo "  42/mod.info: $OLD -> $VERSION"

echo "Done. Verify with:"
echo "  grep -n 'modversion' mod.info 42/mod.info"
