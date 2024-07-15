#!/bin/bash
#
# This source file is part of the Swift.org open source project
#
# Copyright (c) 2022-2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors
#
# Updates the GitHub Pages documentation site thats published from the 'docs'
# subdirectory in the 'gh-pages' branch of this repository.
#
# This script should be run by someone with commit access to the 'gh-pages' branch
# at a regular frequency so that the documentation content on the GitHub Pages site
# is up-to-date with the content in this repo.
#

set -eu

# A `realpath` alternative using the default C implementation.
filepath() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

SWIFT_DOCC_ROOT="$(dirname $(dirname $(filepath $0)))"

DOCC_BUILD_DIR="$SWIFT_DOCC_ROOT"/.build/docc-gh-pages-build
DOCC_OUTPUT_DIR="$DOCC_BUILD_DIR"/SwiftDocC.doccarchive
DOCC_UTILITIES_OUTPUT_DIR="$DOCC_BUILD_DIR"/SwiftDocCUtilities.doccarchive

mkdir -p "$DOCC_UTILITIES_OUTPUT_DIR"

# Set current directory to the repository root
cd "$SWIFT_DOCC_ROOT"

# Use git worktree to checkout the gh-pages branch of this repository in a gh-pages sub-directory
git fetch
git worktree add --checkout gh-pages origin/gh-pages

# Pretty print DocC JSON output so that it can be consistently diffed between commits
export DOCC_JSON_PRETTYPRINT="YES"

# Generate documentation for the 'SwiftDocC' target and output it
# to the /docs subdirectory in the gh-pages worktree directory.

echo -e "\033[34;1m Building SwiftDocC docs at $DOCC_OUTPUT_DIR \033[0m"

swift package \
    --allow-writing-to-directory "$SWIFT_DOCC_ROOT" \
    generate-documentation \
    --target SwiftDocC \
    --disable-indexing \
    --source-service github \
    --source-service-base-url https://github.com/swiftlang/swift-docc/blob/main \
    --checkout-path "$SWIFT_DOCC_ROOT" \
    --transform-for-static-hosting \
    --hosting-base-path swift-docc \
    --output-path "$DOCC_OUTPUT_DIR"

echo -e "\033[34;1m Building SwiftDocC Utilities docs at $DOCC_UTILITIES_OUTPUT_DIR \033[0m"

# Generate documentation for the 'SwiftDocCUtilities' target and output it
# to a temporary output directory in the .build directory.
swift package \
    --allow-writing-to-directory "$DOCC_BUILD_DIR" \
    generate-documentation \
    --target SwiftDocCUtilities \
    --disable-indexing \
    --source-service github \
    --source-service-base-url https://github.com/swiftlang/swift-docc/blob/main \
    --checkout-path "$SWIFT_DOCC_ROOT" \
    --transform-for-static-hosting \
    --hosting-base-path swift-docc \
    --output-path "$DOCC_UTILITIES_OUTPUT_DIR"

echo -e "\033[34;1m Merging docs \033q[0m"

# Remove the output directory so that the merge command can output there
rm -rf "$SWIFT_DOCC_ROOT/gh-pages/docs"

# Merge the SwiftDocCUtilities docs into the primary SwiftDocC docs
swift run docc merge \
    "$DOCC_OUTPUT_DIR" \
    "$DOCC_UTILITIES_OUTPUT_DIR" \
    --output-path "$SWIFT_DOCC_ROOT/gh-pages/docs"

# Save the current commit we've just built documentation from in a variable
CURRENT_COMMIT_HASH=`git rev-parse --short HEAD`

# Commit and push our changes to the gh-pages branch
cd gh-pages
git add docs

if [ -n "$(git status --porcelain)" ]; then
    echo "Documentation changes found. Committing the changes to the 'gh-pages' branch and pushing to origin."
    git commit -m "Update GitHub Pages documentation site to $CURRENT_COMMIT_HASH"
    git push origin HEAD:gh-pages
else
  # No changes found, nothing to commit.
  echo "No documentation changes found."
fi

# Delete the git worktree we created
cd ..
git worktree remove gh-pages
