#!/bin/bash


# Define the path to the supporting documents directory
SUPPORTING_DOCS_DIR="$(cd "$(dirname "$0")" && pwd)/idp5_supporting_files"

echo "$SUPPORTING_DOCS_DIR"
echo "$(cd "$(dirname "$0")" && pwd)"
echo "$(dirname "$0")"

ls -lstr "${SUPPORTING_DOCS_DIR}"
