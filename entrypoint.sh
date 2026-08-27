#!/usr/bin/env bash
set -e

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Architecture not supported: $ARCH"; exit 1 ;;
esac

# Single asset URL (version included in filename)
BINARY_URL="https://github.com/mitigation-dot-team/cli/releases/download/${VERSION}/mitigation_${VERSION}_${OS}_${ARCH}.tar.gz"

echo "Downloading Mitigation Engine for ${OS}/${ARCH} (version ${VERSION})..."
tmpfile=$(mktemp)
# Build Authorization header only for curl; do NOT echo the token or the header
if [ -n "$TOKEN" ]; then
  CURL_AUTH=( -H "Authorization: Bearer $TOKEN" )
elif [ -n "$GITHUB_TOKEN" ]; then
  CURL_AUTH=( -H "Authorization: Bearer $GITHUB_TOKEN" )
else
  CURL_AUTH=()
fi

if ! curl "${CURL_AUTH[@]}" -fSL -o "$tmpfile" "$BINARY_URL"; then
  echo "Failed to download $BINARY_URL"
  rm -f "$tmpfile"
  exit 1
fi

if gzip -t "$tmpfile" >/dev/null 2>&1; then
  tar -xz -f "$tmpfile" -C /tmp
  rm -f "$tmpfile"
  echo "Downloaded and extracted mitigation binary"
else
  echo "Downloaded file is not in gzip format: $BINARY_URL"
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
