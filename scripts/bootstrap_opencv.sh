#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP_PATH="$ROOT_DIR/Framework/opencv2.framework.zip"
CHECKSUM_PATH="$ROOT_DIR/Framework/opencv2.framework.zip.sha256"
FRAMEWORK_DIR="$ROOT_DIR/Framework/opencv2.framework"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "error: missing $ZIP_PATH"
  exit 1
fi

if [[ ! -f "$CHECKSUM_PATH" ]]; then
  echo "error: missing checksum file $CHECKSUM_PATH"
  exit 1
fi

echo "Verifying OpenCV archive checksum..."
(
  cd "$ROOT_DIR/Framework"
  shasum -a 256 -c "$(basename "$CHECKSUM_PATH")"
)

if [[ -d "$FRAMEWORK_DIR" ]]; then
  echo "opencv2.framework already exists: $FRAMEWORK_DIR"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Extracting OpenCV framework..."
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

if [[ -d "$TMP_DIR/opencv2.framework" ]]; then
  mv "$TMP_DIR/opencv2.framework" "$FRAMEWORK_DIR"
elif [[ -d "$TMP_DIR/Framework/opencv2.framework" ]]; then
  mv "$TMP_DIR/Framework/opencv2.framework" "$FRAMEWORK_DIR"
else
  echo "error: failed to find opencv2.framework in archive"
  exit 1
fi

echo "done: $FRAMEWORK_DIR"
