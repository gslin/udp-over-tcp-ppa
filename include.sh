#!/bin/bash

set -eo pipefail

function work {
    local GZIP

    if [[ -x /usr/bin/pigz ]]; then
        GZIP=pigz
    else
        GZIP=gzip
    fi

    if [[ "x${GIT_REPOSITORY_URL}" = x ]]; then
        return 255
    fi

    if [[ "x${NAME}" = x ]]; then
        return 255
    fi

    local TMPDIR
    if [[ "x$TMPDIR" = x ]]; then
        TMPDIR="/tmp/${NAME}"
    fi

    if [[ "x$1" = x ]]; then
        cat <<EOF
Usage:
    $0 <tag or hash> [version name]

Example:
    $0 0.2.0
    $0 6192b33 0.2.0.20160822
EOF
        exit
    fi

    local GIT_HASH
    GIT_HASH="$1"

    local VERSION
    if [[ "x$2" = x ]]; then
        VERSION="$1"
    else
        VERSION="$2"
    fi

    local BASEDIR
    local TARBALL
    local TARBALL_GZ
    BASEDIR="${TMPDIR}/${NAME}-${VERSION}"
    TARBALL="${NAME}-${VERSION}.tar"
    TARBALL_GZ="${TARBALL}.gz"

    rm -rf -- "${TMPDIR}"
    mkdir -p "${TMPDIR}"

    pushd "${TMPDIR}/"
    git clone "${GIT_REPOSITORY_URL}" "${BASEDIR}/"
    cd "${BASEDIR}/"
    git checkout "${GIT_HASH}"

    local GIT_DATETIME
    GIT_DATETIME="$(git log --format='%ci' HEAD...HEAD^ | head -n 1)"
    rm -rf .git/

    if [[ "x${CARGO_VENDOR}" = "xyes" ]]; then
        cargo vendor
        mkdir -p .cargo
        cat >> .cargo/config.toml <<EOF
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF
    fi

    cd ..
    tar -cv --mtime="${GIT_DATETIME}" -f "${TARBALL}" "${NAME}-${VERSION}/"
    ${GZIP} -9 -n "${TARBALL}"
    popd

    rsync -av debian/ "${BASEDIR}/debian/"
    pushd "${BASEDIR}/"
    dh_make -c "${LICENSE}" -f "../${TARBALL_GZ}" -s --yes || true

    # If we have already submitted this version before, use -i to increase version.
    if grep -q "^${NAME} (${VERSION}" debian/changelog; then
        dch --distribution unstable -i
    else
        dch --distribution unstable -v "${VERSION}-unstable~ppa1"
    fi

    popd
    cp "${BASEDIR}/debian/changelog" debian/
}
