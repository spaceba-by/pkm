#!/bin/bash
# ios/Scripts/bootstrap.sh
# Setup script for new developers

set -e

echo "Setting up PKMReader development environment..."

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Please install it first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
brew bundle --file=- <<EOF
brew "swiftlint"
brew "swiftformat"
brew "xcbeautify"
brew "xcodegen"
EOF

# Install Ruby dependencies for Fastlane
echo "Installing Fastlane..."
if ! command -v bundle &> /dev/null; then
    gem install bundler
fi
bundle install

# Generate Xcode project
echo "Generating Xcode project..."
xcodegen generate

# Resolve Swift packages
echo "Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -project PKMReader.xcodeproj -scheme PKMReader

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open PKMReader.xcodeproj in Xcode"
echo "  2. Build and run on simulator"
echo ""
echo "Useful commands:"
echo "  bundle exec fastlane test      # Run all tests"
echo "  bundle exec fastlane lint      # Run SwiftLint"
echo "  bundle exec fastlane format    # Format code"
