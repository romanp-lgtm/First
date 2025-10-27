#!/bin/bash

# Release script for creating tagged releases
# Usage: ./release.sh [patch|minor|major|<version>]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

# Check if working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    print_error "Working directory is not clean. Please commit or stash your changes."
    git status --short
    exit 1
fi

# Get current version from package.json
CURRENT_VERSION=$(node -p "require('./package.json').version")
print_status "Current version: $CURRENT_VERSION"

# Determine new version
if [ $# -eq 0 ]; then
    print_warning "No version specified. Usage: $0 [patch|minor|major|<version>]"
    echo "Current version: $CURRENT_VERSION"
    echo "Examples:"
    echo "  $0 patch    # 1.0.0 -> 1.0.1"
    echo "  $0 minor    # 1.0.0 -> 1.1.0"
    echo "  $0 major    # 1.0.0 -> 2.0.0"
    echo "  $0 1.5.0    # Set specific version"
    exit 1
fi

VERSION_TYPE=$1

# Calculate new version
if [[ "$VERSION_TYPE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    NEW_VERSION=$VERSION_TYPE
    print_status "Setting version to: $NEW_VERSION"
else
    case $VERSION_TYPE in
        patch|minor|major)
            NEW_VERSION=$(npm version $VERSION_TYPE --no-git-tag-version | sed 's/^v//')
            print_status "Bumping $VERSION_TYPE version to: $NEW_VERSION"
            ;;
        *)
            print_error "Invalid version type: $VERSION_TYPE"
            print_error "Use: patch, minor, major, or a specific version (e.g., 1.2.3)"
            exit 1
            ;;
    esac
fi

# Confirm release
echo
print_warning "About to create release:"
echo "  Version: $CURRENT_VERSION -> $NEW_VERSION"
echo "  Tag: v$NEW_VERSION"
echo "  This will:"
echo "    1. Update package.json version"
echo "    2. Commit the version change"
echo "    3. Create and push a git tag"
echo "    4. Trigger the release workflow"
echo "    5. Publish to JFrog Fly"
echo "    6. Create a GitHub release"
echo

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Release cancelled"
    exit 0
fi

# Update package.json version if not already done
if [ "$VERSION_TYPE" != "patch" ] && [ "$VERSION_TYPE" != "minor" ] && [ "$VERSION_TYPE" != "major" ]; then
    npm version $NEW_VERSION --no-git-tag-version
fi

# Commit version change
git add package.json package-lock.json
git commit -m "chore: bump version to $NEW_VERSION"

# Create and push tag
TAG_NAME="v$NEW_VERSION"
git tag -a $TAG_NAME -m "Release $TAG_NAME"

print_status "Pushing changes and tag..."
git push origin main
git push origin $TAG_NAME

print_success "Release $TAG_NAME created and pushed!"
print_status "Check GitHub Actions for release progress: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
print_status "Package will be published to JFrog Fly automatically"
