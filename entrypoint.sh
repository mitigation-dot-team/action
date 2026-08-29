#!/usr/bin/env bash
set -e

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Architecture not supported: ($ARCH)"; exit 1 ;;
esac

VERSION="${VERSION:-latest}"
VERSION_NO_V="${VERSION#v}"

# Try versioned asset (mitigation_<version>_os_arch) first, then unversioned
CANDIDATE_BIN_NAMES=(
  "mitigation_${VERSION_NO_V}_${OS}_${ARCH}.tar.gz"
  "mitigation_${OS}_${ARCH}.tar.gz"
)
TMP_ARCHIVE_TEMPLATE="/tmp/%s"

PRIMARY_REPO_OWNER="mitigation-dot-team"
PRIMARY_REPO_NAME="mitigation"

FALLBACK_REPO="${GITHUB_REPOSITORY:-mitigation-dot-team/action}"

echo "Downloading Mitigation Engine (${VERSION}) for ${OS}/${ARCH}..."

attempt_download() {
  url="$1"
  out="$2"
  echo "Attempting: $url"
  if curl -fSL --retry 3 -o "$out" "$url"; then
    return 0
  else
    echo "Download failed for: $url"
    return 1
  fi
}

TRIED_URLS=()
for BIN_NAME in "${CANDIDATE_BIN_NAMES[@]}"; do
  TMP_ARCHIVE="/tmp/${BIN_NAME}"
  PRIMARY_URL="https://github.com/${PRIMARY_REPO_OWNER}/${PRIMARY_REPO_NAME}/releases/download/${VERSION}/${BIN_NAME}"
  FALLBACK_URL="https://github.com/${FALLBACK_REPO}/releases/download/${VERSION}/${BIN_NAME}"
  NAME="$BIN_NAME"

  # Try API-based download (by asset id) if token available and jq installed
  if command -v jq >/dev/null 2>&1; then
    if [ -n "$TOKEN" ] || [ -n "$GITHUB_TOKEN" ]; then
      API_TOKEN="${TOKEN:-$GITHUB_TOKEN}"
      API_AUTH=( -H "Authorization: Bearer $API_TOKEN" )
      echo "Resolving asset id for $NAME via GitHub API..."
      # Determine release endpoint (tag or latest)
      if [ -n "$VERSION" ] && [ "$VERSION" != "latest" ]; then
        RELEASE_URL="https://api.github.com/repos/${PRIMARY_REPO_OWNER}/${PRIMARY_REPO_NAME}/releases/tags/${VERSION}"
      else
        RELEASE_URL="https://api.github.com/repos/${PRIMARY_REPO_OWNER}/${PRIMARY_REPO_NAME}/releases/latest"
      fi
      ASSET_ID=$(curl -sS "${API_AUTH[@]}" -H "Accept: application/vnd.github+json" "$RELEASE_URL" | jq -r --arg NAME "$NAME" '.assets[] | select(.name==$NAME) | .id')
      if [ -n "$ASSET_ID" ] && [ "$ASSET_ID" != "null" ]; then
        tmpfile=$(mktemp)
        echo "Downloading asset id $ASSET_ID from ${PRIMARY_REPO_OWNER}/${PRIMARY_REPO_NAME}..."
        if curl -sS "${API_AUTH[@]}" -L -H "Accept: application/octet-stream" "https://api.github.com/repos/${PRIMARY_REPO_OWNER}/${PRIMARY_REPO_NAME}/releases/assets/${ASSET_ID}" -o "$tmpfile"; then
          if gzip -t "$tmpfile" >/dev/null 2>&1; then
            tar -xz -f "$tmpfile" -C /tmp
            rm -f "$tmpfile"
            TMP_ARCHIVE="/tmp/${BIN_NAME}"
            echo "Downloaded and extracted mitigation binary from API (primary)"
            break
          else
            echo "Downloaded file from API is not gzip; previewing and skipping"
            head -n 50 "$tmpfile" || true
            rm -f "$tmpfile"
          fi
        else
          echo "Failed to download asset id $ASSET_ID from API (primary)"
        fi
      else
        echo "Asset $NAME not found in release via API (primary)"
      fi
    fi
  else
    echo "jq not found; skipping API asset-id resolution"
  fi

  # Fallback to raw release download URLs
  TRIED_URLS+=("$PRIMARY_URL")
  if attempt_download "$PRIMARY_URL" "$TMP_ARCHIVE"; then
    echo "Downloaded mitigation engine from primary: $PRIMARY_URL"
    break
  fi

  TRIED_URLS+=("$FALLBACK_URL")
  if attempt_download "$FALLBACK_URL" "$TMP_ARCHIVE"; then
    echo "Downloaded mitigation engine from fallback: $FALLBACK_URL"
    break
  fi
done

if [ ! -f "$TMP_ARCHIVE" ]; then
  echo "Error: Failed to download Mitigation Engine. Tried the following URLs:" 
  for u in "${TRIED_URLS[@]}"; do echo "  - $u"; done
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