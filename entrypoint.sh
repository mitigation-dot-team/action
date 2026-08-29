#!/usr/bin/env bash
set -e

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

OWNER="mitigation-dot-team"
REPO="action"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Architecture not supported: $ARCH"; exit 1 ;;
esac

# Resolve version from GitHub API if set to "latest"
if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then
  if [ -n "$TOKEN" ]; then
    RESOLVE_AUTH=( -H "Authorization: Bearer $TOKEN" )
  else
    echo "Error: No token available to resolve the latest release version."
    exit 1
  fi
  RESOLVED_VERSION=$(curl "${RESOLVE_AUTH[@]}" -L "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest" | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  if [ -z "$RESOLVED_VERSION" ]; then
    echo "Error: Failed to resolve latest version from GitHub API."
    exit 1
  fi
  VERSION="$RESOLVED_VERSION"
fi

# Single asset URL (version included in filename)
# Build asset name and attempt to download via GitHub Releases API using asset id
VER_NO_V="${VERSION#v}"
NAME="mitigation_${VER_NO_V}_${OS}_${ARCH}.tar.gz"

echo "Resolving asset id for $NAME (release $VERSION)..."
tmpfile=$(mktemp)

# Prepare auth header for API requests if token available
if [ -n "$TOKEN" ]; then
  API_AUTH=( -H "Authorization: Bearer $TOKEN" )
elif [ -n "$GITHUB_TOKEN" ]; then
  API_AUTH=( -H "Authorization: Bearer $GITHUB_TOKEN" )
else
  API_AUTH=()
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required to parse GitHub API responses in this script." >&2
  echo "Install jq or modify the script to parse JSON another way." >&2
  exit 1
fi

ASSET_ID=$(curl -sS "${API_AUTH[@]}" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${OWNER}/${REPO}/releases/tags/${VERSION}" \
  | jq -r --arg NAME "$NAME" '.assets[] | select(.name==$NAME) | .id')

if [ -z "$ASSET_ID" ] || [ "$ASSET_ID" = "null" ]; then
  echo "Error: asset '$NAME' not found in release '${VERSION}'" >&2
  exit 1
fi

echo "Downloading asset id $ASSET_ID..."
# Download the asset using the special release asset endpoint; request binary stream
if ! curl "${API_AUTH[@]}" -L -H "Accept: application/octet-stream" \
  "https://api.github.com/repos/${OWNER}/${REPO}/releases/assets/${ASSET_ID}" -o "$tmpfile"; then
  echo "Failed to download asset id $ASSET_ID" >&2
  rm -f "$tmpfile"
  exit 1
fi

if gzip -t "$tmpfile" >/dev/null 2>&1; then
  tar -xz -f "$tmpfile" -C /tmp
  rm -f "$tmpfile"
  echo "Downloaded and extracted mitigation binary"
else
  echo "Downloaded file is not in gzip format (asset id $ASSET_ID)" >&2
  echo "Response preview:"
  head -n 50 "$tmpfile" || true
  rm -f "$tmpfile"
  exit 1
fi

if [ ! -f "$DIFF_FILE" ]; then
  echo "Generating a valid diff for the current Pull Request..."
  git diff ORIG_HEAD HEAD > "$DIFF_FILE" || git diff HEAD~1 HEAD > "$DIFF_FILE"
fi

/tmp/mitigation scan \
  --diff-file="$DIFF_FILE" \
  --api-key="$MITIGATION_API_KEY" \
  --output-report=report.md \
  --output-comment=pr-comment.md
