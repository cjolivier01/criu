#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/install-from-nfs.sh [options] [make options...]

Build and stage CRIU as the current (non-root) user, then install the staged
files into / with sudo rsync. This avoids NFS root-squash write failures seen
with "sudo make install" on NFS-backed checkouts.

Options:
  --destdir <path>   Stage install files under this directory.
  --keep-destdir     Keep staged files after successful install.
  -h, --help         Show this help.

Environment:
  SKIP_PIP_INSTALL   Defaults to 1.

Examples:
  scripts/install-from-nfs.sh
  scripts/install-from-nfs.sh --destdir /tmp/criu-stage -j8
  SKIP_PIP_INSTALL=0 scripts/install-from-nfs.sh
EOF
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DESTDIR=""
KEEP_DESTDIR=0
MAKE_ARGS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--destdir)
			if [[ $# -lt 2 ]]; then
				echo "error: --destdir requires a path" >&2
				exit 2
			fi
			DESTDIR="$2"
			shift 2
			;;
		--keep-destdir)
			KEEP_DESTDIR=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		--)
			shift
			MAKE_ARGS+=("$@")
			break
			;;
		*)
			MAKE_ARGS+=("$1")
			shift
			;;
	esac
done

if [[ "${EUID}" -eq 0 ]]; then
	echo "error: run this as a regular user; the script uses sudo only for rsync" >&2
	exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
	echo "error: sudo is required" >&2
	exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
	echo "error: rsync is required" >&2
	exit 1
fi

SKIP_PIP_INSTALL="${SKIP_PIP_INSTALL:-1}"

AUTO_DESTDIR=0
if [[ -z "${DESTDIR}" ]]; then
	DESTDIR="$(mktemp -d -t criu-stage.XXXXXXXX)"
	AUTO_DESTDIR=1
fi

if [[ "${AUTO_DESTDIR}" -eq 1 && "${KEEP_DESTDIR}" -eq 0 ]]; then
	trap 'rm -rf -- "${DESTDIR}"' EXIT
fi

cd -- "${REPO_ROOT}"

echo "Staging install into ${DESTDIR}"
make "${MAKE_ARGS[@]}" DESTDIR="${DESTDIR}" SKIP_PIP_INSTALL="${SKIP_PIP_INSTALL}" install

echo "Installing staged files into / with sudo rsync"
sudo rsync -a "${DESTDIR}/" /

echo "Install complete"
if [[ "${KEEP_DESTDIR}" -eq 1 ]]; then
	echo "Staged files kept at: ${DESTDIR}"
fi
