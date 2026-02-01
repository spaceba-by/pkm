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
brew "mise"
EOF

# Setup mise for project-local Ruby (using precompiled binaries for speed)
echo "Setting up mise for Ruby..."
mise trust
mise settings experimental=true
mise use ruby@3.4.1

# Install Ruby dependencies for Fastlane using mise's Ruby
echo "Installing Fastlane..."
mise exec -- bundle config set --local path 'vendor/bundle'
mise exec -- bundle install

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
