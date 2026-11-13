#!/usr/bin/env bash
# Stops a release whose tag already exists, before anything is published:
# a version can only be released once (CHAN-01). Needs GH_TOKEN.
#   windows/scripts/release/tag-free.sh <tag>
set -euo pipefail
tag="$1"
if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1 \
  || git ls-remote --exit-code --tags "https://github.com/$GITHUB_REPOSITORY.git" "refs/tags/$tag" >/dev/null 2>&1; then
  echo "::error::$tag already exists, so this version can't be released again. Raise the version in windows/package.json."
  exit 1
fi
echo "$tag is free."
