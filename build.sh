#!/bin/bash
# Refactored ArchLinux RootFS Build Engine
# Outputs to format: ArchLinuxArm_Variant_KDE_Date_Time-rootfs.tar.xz

DATE_TIME=$(date +%Y%m%d_%H%M%S)

# Default Arguments
ENABLE_binfmt="false"
VARIANT="custom"
BUILD_KDE="min"

# Parse arguments
while getopts "i:v:K:P:a:c:d:e:f:" opt; do
  case $opt in
    i) DOCKERFILE="$OPTARG" ;;
    v) VARIANT="$OPTARG" ;;
    K) BUILD_KDE="$OPTARG" ;;
    P) PulseAudio="$OPTARG" ;;
    a) ENABLE_binfmt="$OPTARG" ;;
    c) ENABLE_mesa="$OPTARG" ;;
    d) ENABLE_kfgj="$OPTARG" ;;
    e) ENABLE_zip="$OPTARG" ;;
    f) ENABLE_docker="$OPTARG" ;;
    *) echo "Usage: $0 -i <Dockerfile> [-v <variant>]" ; exit 1 ;;
  esac
done

if [ -z "$DOCKERFILE" ] || [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Template file (-i) is required and must exist."
    exit 1
fi

echo "========================================================="
echo " Starting ArchLinux Build Process"
echo " Template  : $DOCKERFILE"
echo " Variant   : $VARIANT"
echo " KDE Type  : $BUILD_KDE"
echo "========================================================="

# Ensure Buildx is ready
if ! docker buildx inspect arch-builder >/dev/null 2>&1; then
    echo "Creating new buildx builder: arch-builder"
    docker buildx create --name arch-builder --driver docker-container --use
else
    echo "Using existing buildx builder: arch-builder"
    docker buildx use arch-builder
fi

docker buildx inspect --bootstrap || echo "Warning: Bootstrap failed, continuing..."

set -e

# Format the requested output name
TEMP_TAR="temp-arch-rootfs.tar"
FINAL_NAME="ArchLinuxArm_${VARIANT}_KDE_${DATE_TIME}-rootfs.tar.xz"

echo "Running Docker Buildx (linux/arm64)..."

docker buildx build \
  --platform linux/arm64 \
  --target export \
  --output type=tar,dest="$TEMP_TAR" \
  --build-arg BUILD_KDE="$BUILD_KDE" \
  --build-arg PulseAudio="$PulseAudio" \
  --build-arg ENABLE_binfmt_ARG="$ENABLE_binfmt" \
  --build-arg ENABLE_mesa_ARG="$ENABLE_mesa" \
  --build-arg ENABLE_kfgj_ARG="$ENABLE_kfgj" \
  --build-arg ENABLE_zip_ARG="$ENABLE_zip" \
  --build-arg ENABLE_docker_ARG="$ENABLE_docker" \
  -f "$DOCKERFILE" \
  .

echo "Compressing build output (xz ultra - Multi-threaded)..."
xz -T0 -9 -f "$TEMP_TAR"

mv "${TEMP_TAR}.xz" "$FINAL_NAME"

echo "========================================================="
echo " Successfully completed: $FINAL_NAME"
echo "========================================================="
