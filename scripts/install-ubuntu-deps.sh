#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
APT_INSTALL="${REPO_ROOT}/contrib/apt-install"
APT_BASE_DEPS="${REPO_ROOT}/contrib/dependencies/apt-packages.sh"

if ! command -v apt-get >/dev/null 2>&1; then
	echo "This script supports Ubuntu/Debian systems with apt-get."
	exit 1
fi

if [ ! -x "${APT_INSTALL}" ] || [ ! -x "${APT_BASE_DEPS}" ]; then
	echo "Missing helper scripts in contrib/."
	exit 1
fi

SUDO=()
if [ "${EUID}" -ne 0 ]; then
	if ! command -v sudo >/dev/null 2>&1; then
		echo "Please run as root or install sudo."
		exit 1
	fi
	SUDO=(sudo -E)
fi

is_installed() {
	dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

EXTRA_PKGS=(
	ca-certificates
	clang
	curl
	libbpf-dev
	libcap2-bin
	libnftables-dev
	nftables
)

# Enable x86 compat build support where available.
if [ "$(uname -m)" = "x86_64" ]; then
	if is_installed crossbuild-essential-arm64 || is_installed gcc-aarch64-linux-gnu || is_installed gcc-15-aarch64-linux-gnu; then
		echo "Skipping gcc-multilib (conflicts with installed arm64 cross-compiler packages)."
	else
		EXTRA_PKGS+=(gcc-multilib)
	fi
fi

"${SUDO[@]}" "${APT_BASE_DEPS}"
"${SUDO[@]}" "${APT_INSTALL}" "${EXTRA_PKGS[@]}"

echo "Ubuntu build/test dependencies installed."
