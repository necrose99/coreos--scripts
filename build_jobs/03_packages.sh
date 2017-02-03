#!/bin/bash
#
# Jenkins job for building board binary packages.
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
#   MANIFEST_NAME=release.xml
#     Git URL, tag, and manifest file for this build.
#
#   MANIFEST_REF=refs/tags/${tag}
#     Git branch or tag in github.com/coreos/manifest to build
#
#   MANIFEST_URL=https://github.com/coreos/manifest-builds.git
#     Git repository of manifest-builds.
#
# Input Artifacts:
#
#   $WORKSPACE/bin/cork from a recent mantle build.
#
# Secrets:
#
#   GOOGLE_APPLICATION_CREDENTIALS=
#     JSON file defining a Google service account for uploading files.
#
# Output:
#
#   Uploads binary packages to COREOS_DEV_BUILDS

set -ex

# use a ccache dir that persists across sdk recreations
# XXX: alternatively use a ccache dir that is usable by all jobs on a given node.
mkdir -p .cache/ccache

enter() {
  ./bin/cork enter --experimental -- env \
    CCACHE_DIR="/mnt/host/source/.cache/ccache" \
    CCACHE_MAXSIZE="5G" \
    COREOS_DEV_BUILDS="http://storage.googleapis.com/${COREOS_DEV_BUILDS}" \
    "$@"
}

script() {
  local script="/mnt/host/source/src/scripts/${1}"; shift
  enter "${script}" "$@"
}

source .repo/manifests/version.txt
export COREOS_BUILD_ID

# figure out if ccache is doing us any good in this scheme
enter ccache --zero-stats

#if [[ "${COREOS_OFFICIAL:-0}" -eq 1 ]]; then
  script setup_board --board=${BOARD} \
                     --getbinpkgver=${COREOS_VERSION} \
                     --toolchainpkgonly \
                     --force
#fi
script build_packages --board=${BOARD} \
                      --skip_chroot_upgrade \
                      --getbinpkgver=${COREOS_VERSION} \
                      --toolchainpkgonly \
                      --upload --upload_root gs://${COREOS_DEV_BUILDS}

enter ccache --show-stats
