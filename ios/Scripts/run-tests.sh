#!/bin/bash
# ios/Scripts/run-tests.sh
# Local test runner script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$IOS_DIR"

# Default values
SCHEME="PKMReader"
DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.0'
TEST_TYPE="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --unit)
            TEST_TYPE="unit"
            shift
            ;;
        --ui)
            TEST_TYPE="ui"
            shift
            ;;
        --destination)
            DESTINATION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--unit|--ui] [--destination 'platform=...']"
            exit 1
            ;;
    esac
done

echo "Running $TEST_TYPE tests..."

XCODEBUILD_ARGS=(
    -project PKMReader.xcodeproj
    -scheme "$SCHEME"
    -destination "$DESTINATION"
    -configuration Debug
    CODE_SIGN_IDENTITY=""
    CODE_SIGNING_REQUIRED=NO
)

case $TEST_TYPE in
    unit)
        XCODEBUILD_ARGS+=(-only-testing:PKMReaderTests)
        ;;
    ui)
        XCODEBUILD_ARGS+=(-only-testing:PKMReaderUITests)
        ;;
esac

set -o pipefail
if command -v xcbeautify &> /dev/null; then
    xcodebuild test "${XCODEBUILD_ARGS[@]}" 2>&1 | xcbeautify
else
    xcodebuild test "${XCODEBUILD_ARGS[@]}"
fi

echo "Tests completed successfully!"
