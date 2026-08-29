#!/usr/bin/env bash
set -e

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Architecture not supported: ($ARCH)"; exit 1 ;;
esac

BINARY_URL="https://github.com/mitigation-dot-team/action/releases/download/${VERSION}/mitigation_${OS}_${ARCH}.tar.gz"

echo "Downloading Mitigation Engine (${VERSION}) for ${OS}/${ARCH}..."
TMP_ARCHIVE="/tmp/mitigation_${VERSION}_${OS}_${ARCH}.tar.gz"

if ! curl -fSL --retry 3 -o "$TMP_ARCHIVE" "$BINARY_URL"; then
  echo "Error: Failed to download Mitigation Engine from $BINARY_URL"
  exit 1
fi

if ! tar -xz -f "$TMP_ARCHIVE" -C /tmp; then
  echo "Error: Failed to extract $TMP_ARCHIVE"
  exit 1
fi

if [ ! -f "$DIFF_FILE" ]; then
  echo "Generating a valid diff for the current Pull Request..."
  git diff ORIG_HEAD HEAD > "$DIFF_FILE" || git diff HEAD~1 HEAD > "$DIFF_FILE" || true
fi

if [ ! -s "$DIFF_FILE" ]; then
  echo "No changes detected in diff file '$DIFF_FILE'. Exiting with code 1 as requested."
  exit 1
fi

if [ ! -x "/tmp/mitigation" ]; then
  echo "Error: mitigation binary not found or not executable at /tmp/mitigation"
  ls -la /tmp || true
  exit 1
fi

/tmp/mitigation scan \
  --diff-file="$DIFF_FILE" \
  --api-key="$MITIGATION_API_KEY" \
  --output-report=report.md \
  --output-comment=pr-comment.md