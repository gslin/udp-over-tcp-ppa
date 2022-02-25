#!/bin/bash

. $(dirname $0)/ppa-tools/include.sh

CARGO_VENDOR=yes
GIT_REPOSITORY_URL=https://github.com/mullvad/udp-over-tcp.git
LICENSE=mit
NAME=udp-over-tcp

work $*
