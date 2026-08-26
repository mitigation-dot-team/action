#!/usr/bin/env bash
set -e

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Arquitectura no soportada: $ARCH"; exit 1 ;;
esac

BINARY_URL="https://github.com/mitigation-dot-team/mitigation-releases/releases/download/${VERSION}/mitigation_${OS}_${ARCH}.tar.gz"

echo "Downloading Mitigation Engine (${VERSION}) for ${OS}/${ARCH}..."
curl -sSL "$BINARY_URL" | tar -xz -C /tmp

# Generar diff del PR si no existe el archivo especificado
if [ ! -f "$DIFF_FILE" ]; then
  echo "Generando diff del PR actual..."
  git diff ORIG_HEAD HEAD > "$DIFF_FILE" || git diff HEAD~1 HEAD > "$DIFF_FILE"
fi

# Ejecutar el binario compilado (sin exponer el código fuente)
/tmp/mitigation scan \
  --diff-file="$DIFF_FILE" \
  --api-key="$MITIGATION_API_KEY" \
  --output-report=report.md \
  --output-comment=pr-comment.md
