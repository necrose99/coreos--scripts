#!/bin/bash
#
# Jenkins job for building the base production image and dev container.
#
# Input Parameters:
#
#   BOARD=amd64-usr
#     Target board to build.
#
#   COREOS_DEV_BUILDS=builds.developer.core-os.net
#     Upload root for binary SDK and board packages.
#
#   COREOS_OFFICIAL=0
#     Set to 1 when building official releases.
#
#   COREOS_REL_BUILDS=builds.release.core-os.net
#     Upload root for images.
#
#   GPG_USER_ID=${GPG_USER_ID}
#     User ID for GPG_SECRET_KEY_FILE.
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

set -ex

# first thing, clear out old images
sudo rm -rf src/build

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

sudo rm -rf chroot/build
script setup_board --board=${BOARD} \
                   --getbinpkgver="${COREOS_VERSION}" \
                   --regen_configs_only

if [[ "${COREOS_OFFICIAL}" -eq 1 ]]; then
  GROUP=stable
  UPLOAD=gs://${COREOS_REL_BUILDS}/stable
  script set_official --board=${BOARD} --official
else
  GROUP=developer
  UPLOAD=gs://${COREOS_DEV_BUILDS}/images
  script set_official --board=${BOARD} --noofficial
fi

script build_image --board=${BOARD} \
                   --group=${GROUP} \
                   --getbinpkg \
                   --getbinpkgver="${COREOS_VERSION}" \
                   --sign=${GPG_USER_ID} \
                   --sign_digests=${GPG_USER_ID} \
                   --upload_root=${UPLOAD} \
                   --upload prod container

if [[ "${COREOS_OFFICIAL}" -eq 1 ]]; then
  script image_set_group --board=${BOARD} \
                         --group=alpha \
                         --sign=${GPG_USER_ID} \
                         --sign_digests=${GPG_USER_ID} \
                         --upload_root=gs://${COREOS_REL_BUILDS}/alpha \
                         --upload
  script image_set_group --board=${BOARD} \
                         --group=beta \
                         --sign=${GPG_USER_ID} \
                         --sign_digests=${GPG_USER_ID} \
                         --upload_root=gs://${COREOS_REL_BUILDS}/beta \
                         --upload
fi
