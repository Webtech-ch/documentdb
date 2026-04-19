#!/bin/bash

set -euo pipefail

# set script_dir to the parent directory of the script (repo root)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Function to display help message
function show_help {
    echo "Usage: $0 [--pg <PG_VERSION>] [--tag <IMAGE_TAG>] [-h|--help]"
    echo ""
    echo "Description:"
    echo "  Builds the documentdb-local Docker image (equivalent to ghcr.io/documentdb/documentdb/documentdb-local)."
    echo "  First builds the .deb package for Debian Trixie (deb13), then builds the gateway Docker image."
    echo ""
    echo "Optional Arguments:"
    echo "  --pg     PG version to build for. Possible values: [15, 16, 17]. Default: 17"
    echo "  --tag    Docker image tag. Default: documentdb-local"
    echo "  -h, --help  Display this help message."
    exit 0
}

# Defaults (matching the official 'latest' image)
PG="17"
IMAGE_TAG="documentdb"
OUTPUT_DIR="downloaded-artifacts"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pg)
            shift
            PG="$1"
            ;;
        --tag)
            shift
            IMAGE_TAG="$1"
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown argument: $1"
            show_help
            ;;
    esac
    shift
done

cd "$script_dir"

echo "==> Step 1: Building .deb package (os=deb13, pg=${PG})"
./packaging/build_packages.sh --os deb13 --pg "${PG}" --output-dir "${OUTPUT_DIR}"

echo "==> Step 2: Locating .deb package"
DEB_FILE=$(ls "${OUTPUT_DIR}" | grep -v 'dbgsym' | grep '\.deb$' | head -n 1)
if [[ -z "$DEB_FILE" ]]; then
    echo "ERROR: No .deb package found in ${OUTPUT_DIR}" >&2
    exit 1
fi
DEB_PACKAGE_REL_PATH="${OUTPUT_DIR}/${DEB_FILE}"
echo "    Found: ${DEB_PACKAGE_REL_PATH}"

echo "==> Step 3: Building Docker image '${IMAGE_TAG}'"
docker build \
   --build-arg BASE_IMAGE=debian:trixie-slim \
   --build-arg POSTGRES_VERSION="${PG}" \
   --build-arg DEB_PACKAGE_REL_PATH="${DEB_PACKAGE_REL_PATH}" \
   -t "${IMAGE_TAG}" \
   -f .github/containers/Build-Ubuntu/Dockerfile_gateway .

echo ""
echo "Build complete. Image tagged as '${IMAGE_TAG}'."
echo "Run it with:"
echo "  docker run -dt -p 27017:27017 --name documentdb-container ${IMAGE_TAG} --documentdb-user <USER> --documentdb-password <PASS>"
