#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is not installed."
  echo "Install with: brew install xcodegen"
  exit 1
fi

echo "Generating Xcode project from project.yml..."
xcodegen generate

echo "Done. Open RAMSBuilder.xcodeproj in Xcode."
