#!/bin/bash
#
# Jenkins job for building final VM and OEM target images.
#
# Input Parameters:
#
#   BOARD=amd64-usr
#     Target board to build.
#
#   COREOS_DEV_BUILDS=builds.developer.core-os.net
#     Upload root for binary SDK and board packages.
#
#   COREOS_DL_ROOT=release.core-os.net
#     Download root for images.
#
#   COREOS_OFFICIAL=0
#     Set to 1 when building official releases.
#
#   COREOS_REL_BUILDS=builds.release.core-os.net
#     Upload root for images.
#
#   FORMAT=qemu
#     Target VM or OEM.
#
#   GPG_USER_ID=${GPG_USER_ID}
#     User ID for GPG_SECRET_KEY_FILE.
#
#   GROUP=developer
#     Target update group: {developer, alpha, beta, stable}
#
#   MANIFEST_NAME=release.xml
#     Git URL, tag, and manifest file for this build.
#
#   MANIFEST_REF=refs/tags/${tag}
#     Git branch or tag in github.com/coreos/manifest to build
#
#   MANIFEST_URL=https://github.com/coreos/manifest-builds.git
#     Git repository of manifest-builds.
#
#   USE_CACHE=false
#     Enable use of any binary packages cached locally from previous builds.
#     Currently not safe to enable, particularly bad with multiple branches.
#
# Input Artifacts:
#
#   $WORKSPACE/bin/cork from a recent mantle build.
#
# Secrets:
#
#   GPG_SECRET_KEY_FILE=
#     Exported GPG public/private key used to sign uploaded files.
#
#   GOOGLE_APPLICATION_CREDENTIALS=
#     JSON file defining a Google service account for uploading files.
#
# Output:
#
#   Uploads test branch images to COREOS_REL_BUILDS and official images to
#   COREOS_DEV_BUILDS.
#   Writes gce.properties for triggering a GCE test job if applicable.

set -ex

rm -f gce.properties
sudo rm -rf tmp

# check that the matrix didn't go bananas
if [[ "${COREOS_OFFICIAL}" -eq 1 ]]; then
  [[ "${GROUP}" != developer ]]
else
  [[ "${GROUP}" == developer ]]
fi

enter() {
  ./bin/cork enter --experimental -- env \
    COREOS_DEV_BUILDS="http://storage.googleapis.com/${COREOS_DEV_BUILDS}" \
    "$@"
}

script() {
  local script="/mnt/host/source/src/scripts/${1}"; shift
  enter "${script}" "$@"
}

source .repo/manifests/version.txt
export COREOS_BUILD_ID

# Set up GPG for signing images
export GNUPGHOME="${PWD}/.gnupg"
rm -rf "${GNUPGHOME}"
trap "rm -rf '${GNUPGHOME}'" EXIT
mkdir --mode=0700 "${GNUPGHOME}"
gpg --import "${GPG_SECRET_KEY_FILE}"

if [[ "${GROUP}" == developer ]]; then
  root="gs://${COREOS_DEV_BUILDS}/images"
  dlroot=""
else
  root="gs://${COREOS_REL_BUILDS}/${GROUP}"
  dlroot="--download_root https://${GROUP}.${COREOS_DL_ROOT}"
fi

mkdir -p src tmp
./bin/cork download-image --root="${root}/boards/${BOARD}/${COREOS_VERSION}" \
                          --json-key="${GOOGLE_APPLICATION_CREDENTIALS}" \
                          --cache-dir=./src \
                          --platform=qemu
img=src/coreos_production_image.bin
if [[ "${img}.bz2" -nt "${img}" ]]; then
  enter lbunzip2 -k -f "/mnt/host/source/${img}.bz2"
fi

sudo rm -rf chroot/build
script image_to_vm.sh --board=${BOARD} \
                      --format=${FORMAT} \
                      --prod_image \
                      --getbinpkg \
                      --getbinpkgver=${COREOS_VERSION} \
                      --from=/mnt/host/source/src/ \
                      --to=/mnt/host/source/tmp/ \
                      --sign=${GPG_USER_ID} \
                      --sign_digests=${GPG_USER_ID} \
                      --upload_root="${root}" \
                      --upload ${dlroot}
