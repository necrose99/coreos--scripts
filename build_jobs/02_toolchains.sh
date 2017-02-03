#!/bin/bash
#
# Jenkins job for building the SDK's cross toolchains.
#
# Input Parameters:
#
#   COREOS_DEV_BUILDS=builds.developer.core-os.net
#     Upload root for binary SDK and board packages.
#
#   COREOS_OFFICIAL=0
#     Set to 1 when building official releases.
#
#   GPG_USER_ID=buildbot@coreos.com
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
#   Uploads binary packages to COREOS_DEV_BUILDS

set -ex

enter() {
  ./bin/cork enter --experimental -- "$@"
}

source .repo/manifests/version.txt
export COREOS_BUILD_ID

# Set up GPG for signing images
export GNUPGHOME="${PWD}/.gnupg"
sudo rm -rf "${GNUPGHOME}"
trap "sudo rm -rf '${GNUPGHOME}'" EXIT
mkdir --mode=0700 "${GNUPGHOME}"
gpg --import "${GPG_SECRET_KEY_FILE}"

# Wipe all of catalyst or just clear out old tarballs taking up space
if [[ "${COREOS_OFFICIAL:-0}" -eq 1 || "$USE_CACHE" == false ]]; then
  sudo rm -rf src/build/catalyst
fi
sudo rm -rf src/build/catalyst/builds

enter sudo emerge -uv --jobs=2 catalyst
enter sudo /mnt/host/source/src/scripts/build_toolchains \
  --sign ${GPG_USER_ID} --sign_digests ${GPG_USER_ID} \
  --upload --upload_root gs://${COREOS_DEV_BUILDS}
