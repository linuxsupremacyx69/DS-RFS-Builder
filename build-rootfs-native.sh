#!/bin/bash
: "${VERSION:=dev}"
DATE=$(date +%Y%m%d)      # Get current date
ARCH=$(uname -m)          # Get current system architecture
ENABLE_binfmt="false"
# Parse input parameters (-i specifies Dockerfile, -v specifies version number)
while getopts "i:v:K:P:a:b:c:d:e:f:g:h:j:" opt; do
  case $opt in
    i) DOCKERFILE="$OPTARG" ;; # Assign -i parameter to DOCKERFILE variable
    v) VERSION="$OPTARG" ;;    # Assign -v parameter to VERSION variable
    K) BUILD_KDE="$OPTARG"  ;;
    P) PulseAudio="$OPTARG"  ;;
    g) ENABLE_en_us="$OPTARG"  ;; # English language support
    a) ENABLE_binfmt="$OPTARG" ;; # -a Cross-architecture support
    b) ENABLE_yj="$OPTARG" ;; 
    c) ENABLE_mesa="$OPTARG" ;;
    d) ENABLE_kfgj="$OPTARG" ;; 
    e) ENABLE_zip="$OPTARG" ;; 
    f) ENABLE_docker="$OPTARG" ;; 
    h) ENABLE_srf="$OPTARG" ;; # Input method fcitx5
    j) ENABLE_tmoe="$OPTARG" ;; # tmoe
    *) echo "Usage: $0 -i <template.Dockerfile> [-v <version>]" ; exit 1 ;;
  esac
done

# Validation: Check if the Dockerfile template file was passed
if [ -z "$DOCKERFILE" ]; then
    echo "Error: The template file must be specified using the -i parameter."
    exit 1
fi

# Validation: Check if the specified Dockerfile exists locally
if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Cannot find template file '$DOCKERFILE'."
    exit 1
fi

# Extract prefix name (e.g., extract Debian-13-KDE from Debian-13-KDE.Dockerfile)
PREFIX=$(echo "$DOCKERFILE" | sed 's/\.Dockerfile//')

echo "========================================================="
echo " Starting build project : $PREFIX"
echo " Using template file : $DOCKERFILE"
echo " Current build version : $VERSION"
echo " Cross-architecture : $ENABLE_binfmt"
echo " Container hardware and network recognition: $ENABLE_yj"
echo "========================================================="

# 1. Environment initialization (Native architecture mode)
echo "Ensuring native build environment..."
# In Native mode, there is no need to initialize QEMU emulator or binfmt cross-architecture support

# 2. Cross-platform compiler (Buildx Builder) setup
# Check if a buildx builder named 'droidspaces-builder' exists, create if not
if ! docker buildx inspect droidspaces-builder >/dev/null 2>&1; then
    echo "Creating new buildx builder: droidspaces-builder"
    docker buildx create --name droidspaces-builder --driver docker-container --use
else
    echo "Using existing buildx builder: droidspaces-builder"
    docker buildx use droidspaces-builder
fi

# Bootstrap the builder to ensure it is in a ready state
docker buildx inspect --bootstrap || echo "Warning: Bootstrap failed, attempting to continue..."

# Enable strict mode: if any subsequent command fails (returns non-zero status code), the script aborts immediately
set -e

# 3. Core build process
TEMP_TAR="custom-${PREFIX}-rootfs.tar"
FINAL_NAME="${PREFIX}-Droidspaces-RootFS-${Arch}-${DATE}-${VERSION}.tar.xz"

echo "Running Docker Build (Native mode)..."

docker buildx build \
  --target export \
  --output type=tar,dest="$TEMP_TAR" \
  --build-arg BUILD_KDE="$BUILD_KDE" \
  --build-arg PulseAudio="$PulseAudio" \
  --build-arg ENABLE_en_us_ARG="$ENABLE_en_us" \
  --build-arg ENABLE_binfmt_ARG="$ENABLE_binfmt" \
  --build-arg ENABLE_yj_ARG="$ENABLE_yj" \
  --build-arg ENABLE_mesa_ARG="$ENABLE_mesa" \
  --build-arg ENABLE_kfgj_ARG="$ENABLE_kfgj" \
  --build-arg ENABLE_zip_ARG="$ENABLE_zip" \
  --build-arg ENABLE_docker_ARG="$ENABLE_docker" \
  --build-arg ENABLE_srf_ARG="$ENABLE_srf" \
  --build-arg ENABLE_tmoe_ARG="$ENABLE_tmoe" \
  -f "$DOCKERFILE" \
  .

echo "Compressing build artifacts (using xz maximum compression - multi-threading enabled)..."
xz -T0 -9 -f "$TEMP_TAR"

echo "Renaming final file: $FINAL_NAME"
mv "${TEMP_TAR}.xz" "$FINAL_NAME"

echo "========================================================="
echo " Congratulations! Build successfully Completed: $FINAL_NAME"
echo "========================================================="

