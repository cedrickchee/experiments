#!/bin/bash

ROOT=$HOME/software
REPO_URL=https://ziglang.org/download/index.json
TMPDIR=/tmp/zig-update

REPO_ENTRY=x86_64-linux

function die()
{
	echo "$@"
	rm -r ${TMPDIR}
	exit 1
}

if [ ! -d "${ROOT}" ]; then
	echo "Root directory ${ROOT} does not exist!"
	exit 1
fi

REPO="${TMPDIR}/zig-repo.json"

mkdir -p "${TMPDIR}"
touch "${ROOT}/zig-current"

echo "Downloading repository..."

curl -s "${REPO_URL}" | jq ".master[\"${REPO_ENTRY}\"]" > "${REPO}" || die "failed to aquire repo!"

TARBALL=$(jq --raw-output '.tarball' ${REPO})
SHASUM=$(jq --raw-output '.shasum' ${REPO})
SIZE=$(jq --raw-output '.size' ${REPO})

VERSION=$(basename ${TARBALL} | sed 's/.tar.xz$//')

[ "${VERSION}" != "" ] || die "Could not extract version info"

if [ -d "${ROOT}/${VERSION}" ]; then
	echo "${VERSION} is already the current version!"
else
	echo "Updating to ${VERSION}"

	if curl "${TARBALL}" | tar -xJC ${ROOT}; then
		rm "${ROOT}/zig-current" || die "failed to set new symlink!"
		ln -s "${ROOT}/${VERSION}" "${ROOT}/zig-current" || die "failed to set new symlink!"
	else
		echo "Update failed!"
		rm -rf "${ROOT}/${VERSION}"
	fi
fi

# symlink
ln -s "${ROOT}/zig-current/zig" ~/.local/bin

echo "Current version is now: $(zig version)"

rm -r ${TMPDIR}
