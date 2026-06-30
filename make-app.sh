#!/bin/bash
# Build with SPM, assemble + sign /Applications/loqui.app, launch.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build"
swift build

./assemble-app.sh .build/debug

open /Applications/loqui.app
echo "==> launched loqui.app"
