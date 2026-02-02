#!/bin/bash
# ios/Scripts/generate-project.sh
# Regenerate Xcode project from project.yml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$IOS_DIR"

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "XcodeGen not found. Installing via Homebrew..."
    brew install xcodegen
fi

echo "Generating Xcode project from project.yml..."
xcodegen generate

echo "Project generated successfully!"
echo "Open PKMReader.xcodeproj in Xcode to start developing."
