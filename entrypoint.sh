#!/usr/bin/env bash
set -e

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Architecture not supported: $ARCH"; exit 1 ;;
esac

# Try both asset name patterns: with version in filename, and without
BINARY_URLS=(
  "https://github.com/mitigation-dot-team/cli/releases/download/${VERSION}/mitigation_${VERSION}_${OS}_${ARCH}.tar.gz"
  "https://github.com/mitigation-dot-team/cli/releases/download/${VERSION}/mitigation_${OS}_${ARCH}.tar.gz"
)

echo "Downloading Mitigation Engine (${VERSION}) for ${OS}/${ARCH})..."
success=0
for BINARY_URL in "${BINARY_URLS[@]}"; do
  tmpfile=$(mktemp)
  # Use provided token if available (secrets.TOKEN, GITHUB_TOKEN, or PAT)
  AUTH_HDR=()
  if [ -n "$TOKEN" ]; then
    AUTH_HDR=( -H "Authorization: Bearer $TOKEN" )
  elif [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HDR=( -H "Authorization: Bearer $GITHUB_TOKEN" )
  fi

  if curl "${AUTH_HDR[@]}" -fSL -o "$tmpfile" "$BINARY_URL"; then
    if gzip -t "$tmpfile" >/dev/null 2>&1; then
      tar -xz -f "$tmpfile" -C /tmp
      rm -f "$tmpfile"
      success=1
      echo "Downloaded and extracted: $BINARY_URL"
      break
    else
      echo "Downloaded file from $BINARY_URL is not gzip format (maybe 404 HTML)."
      echo "Response preview:"
      head -n 50 "$tmpfile" || true
      rm -f "$tmpfile"
    fi
  else
    echo "Failed to download $BINARY_URL"
    rm -f "$tmpfile"
  fi
done

if [ "$success" -ne 1 ]; then
  echo "Could not download a valid mitigation binary for ${VERSION} / ${OS}/${ARCH}"
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
