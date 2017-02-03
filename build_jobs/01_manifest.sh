#!/bin/bash
#
# Jenkins job for creating build manifests.
#
# Input Parameters:
#
#   COREOS_DEV_BUILDS=builds.developer.core-os.net
#     Upload root for binary SDK and board packages.
#
#   COREOS_REL_BUILDS=builds.release.core-os.net
#     Upload root for images.
#
#   GIT_AUTHOR_EMAIL=jenkins@jenkins.coreos.systems
#     Jenkins commit author.
#
#   GIT_AUTHOR_NAME="CoreOS Jenkins"
#     Jenkins commit author.
#
#   GPG_USER_ID=buildbot@coreos.com
#     User ID for GPG_SECRET_KEY_FILE.
#
#   LOCAL_MANIFEST=
#     Repo local manifest to amend the branch's default manifest with.
#     https://wiki.cyanogenmod.org/w/Doc:_Using_manifests#The_local_manifest
#
#   MANIFEST_REF=master
#     Git branch or tag in github.com/coreos/manifest to build
#
#   MANIFEST_URL=https://github.com/coreos/manifest-builds.git
#     Git repository of manifest-builds.
#
# Input Artifacts:
#
#   $WORKSPACE/bin/cork from a recent mantle build.
#
# Git:
#
#   MANIFEST_URL checked out to $WORKSPACE/manifest
#   Requires SSH push access to MANIFEST_URL
#
# Output:
#
#   Pushes build tag to MANIFEST_URL.
#   Writes manifest.properties w/ parameters for sdk and toolchain jobs.

set -ex

COREOS_DEV_BUILDS="glevand-dev-builds"
COREOS_REL_BUILDS="glevand-dev-builds/releases"
GIT_AUTHOR_EMAIL="jenkins@openhuawei.com"
GIT_AUTHOR_NAME="OpenHuawei Jenkins"
GPG_USER_ID="jenkins@openhuawei.com"
MANIFEST_URL="https://github.com/glevand/manifest-builds.git"

export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"

finish() {
  local tag="$1"
  git -C "${WORKSPACE}/manifest" push \
    "ssh://git@${MANIFEST_URL#https://}" \
    "refs/tags/${tag}:refs/tags/${tag}"
  tee "${WORKSPACE}/manifest.properties" <<EOF
COREOS_DEV_BUILDS = ${COREOS_DEV_BUILDS}
COREOS_OFFICIAL = ${COREOS_OFFICIAL:-0}
COREOS_REL_BUILDS = ${COREOS_REL_BUILDS}
GPG_USER_ID = ${GPG_USER_ID}
LOCAL_MANIFEST = ${LOCAL_MANIFEST}
MANIFEST_NAME = release.xml
MANIFEST_REF = refs/tags/${tag}
MANIFEST_URL = ${MANIFEST_URL}
EOF
}

# Branches are of the form remote-name/branch-name. Tags are just tag-name.
# If we have a release tag use it, for branches we need to make a tag.
COREOS_OFFICIAL=0
if [[ "${GIT_BRANCH}" != */* ]]; then
  COREOS_OFFICIAL=1
  finish "${GIT_BRANCH}"
  exit
fi

MANIFEST_BRANCH="${GIT_BRANCH##*/}"
MANIFEST_NAME="${MANIFEST_BRANCH}.xml"
[[ -f "manifest/${MANIFEST_NAME}" ]]

source manifest/version.txt
export COREOS_BUILD_ID="${MANIFEST_BRANCH}-${BUILD_NUMBER}"

# hack to get repo to set things up using the manifest repo we already have
# (amazing that it tolerates this considering it usually is so intolerant)
mkdir -p .repo
ln -sfT ../manifest .repo/manifests
ln -sfT ../manifest/.git .repo/manifests.git

# Cleanup/setup local manifests
rm -rf .repo/local_manifests
if [[ -n "${LOCAL_MANIFEST}" ]]; then
  mkdir -p .repo/local_manifests
  cat >.repo/local_manifests/local.xml <<<"${LOCAL_MANIFEST}"
fi

sudo systemctl status systemd-binfmt.service

# Cleanup any failed jenkins build
./bin/cork delete

./bin/cork update --create --downgrade-replace --verbose \
                  --manifest-url "${GIT_URL}" \
                  --manifest-branch "${GIT_COMMIT}" \
                  --manifest-name "${MANIFEST_NAME}" \
                  --new-version "${COREOS_VERSION}" \
                  --sdk-version "${COREOS_SDK_VERSION}"

./bin/cork enter --experimental -- sh -c \
  "pwd; repo manifest -r > '/mnt/host/source/manifest/${COREOS_BUILD_ID}.xml'"

cd manifest
git add "${COREOS_BUILD_ID}.xml" 

ln -sf "${COREOS_BUILD_ID}.xml" default.xml
ln -sf "${COREOS_BUILD_ID}.xml" release.xml
git add default.xml release.xml

tee version.txt <<EOF
COREOS_VERSION=${COREOS_VERSION_ID}+${COREOS_BUILD_ID}
COREOS_VERSION_ID=${COREOS_VERSION_ID}
COREOS_BUILD_ID=${COREOS_BUILD_ID}
COREOS_SDK_VERSION=${COREOS_SDK_VERSION}
EOF
git add version.txt

export GIT_AUTHOR_EMAIL GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}"
export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME}"

git commit \
  -m "${COREOS_BUILD_ID}: add build manifest" \
  -m "Based on ${GIT_URL} branch ${MANIFEST_BRANCH}" \
  -m "${BUILD_URL}"
git tag -m "${COREOS_BUILD_ID}" "${COREOS_BUILD_ID}" HEAD

# assert that what we just did will work, update symlink because verify doesn't have a --manifest-name option yet
cd "${WORKSPACE}"
ln -sf "manifests/${COREOS_BUILD_ID}.xml" .repo/manifest.xml
./bin/cork verify

finish "${COREOS_BUILD_ID}"
