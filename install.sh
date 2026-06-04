#!/bin/sh
# install.sh -- install EDM CICS Quadlet units, create ZFS datasets,
# and pre-create named Podman volumes.
#
# Follows established practices from fts-quadlet-setup and pbx-quadlet-setup:
# - ZFS datasets at storage/containers/<name> and storage/users/<name>
# - Named volumes bound to ZFS datasets (not %h path assumptions)
# - HAProxy for TLS termination
# - rootless Podman throughout
set -e

QUADLET_DIR="${HOME}/.config/containers/systemd"
ENV_DIR="${HOME}/.config/containers"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ZFS pool root — override if your pool is named differently
ZFS_POOL="${ZFS_POOL:-storage}"

die() { echo "ERROR: $1" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "$1 not found — install it first"
}

require_cmd podman
require_cmd zfs

echo "==> Installing EDM CICS Quadlet units..."

mkdir -p "${QUADLET_DIR}" "${ENV_DIR}"

# Install unit files
for f in "${SCRIPT_DIR}/quadlet/"*; do
    cp "$f" "${QUADLET_DIR}/"
    printf "    installed: %s\n" "$(basename "$f")"
done

# Install env file if not present
if [ ! -f "${ENV_DIR}/edm.env" ]; then
    cp "${SCRIPT_DIR}/.env.example" "${ENV_DIR}/edm.env"
    echo "    installed: edm.env (set POSTGRES_PASSWORD before starting)"
else
    echo "    skipped: edm.env already exists"
fi

# Create ZFS datasets
echo "==> Creating ZFS datasets under ${ZFS_POOL}/..."
for ds in     containers/edm-postgres     containers/edm-bricks     users/edm-runtime     users/edm-sql; do
    if zfs list "${ZFS_POOL}/${ds}" >/dev/null 2>&1; then
        echo "    exists: ${ZFS_POOL}/${ds}"
    else
        zfs create -p "${ZFS_POOL}/${ds}"
        echo "    created: ${ZFS_POOL}/${ds}"
    fi
done

# Populate edm-runtime and edm-sql from submodule if empty
if [ -d "${SCRIPT_DIR}/edm-cics/runtime" ]; then
    if [ -z "$(ls -A "/${ZFS_POOL}/users/edm-runtime" 2>/dev/null)" ]; then
        echo "==> Populating edm-runtime from submodule..."
        cp -r "${SCRIPT_DIR}/edm-cics/runtime/."               "/${ZFS_POOL}/users/edm-runtime/"
    fi
fi
if [ -d "${SCRIPT_DIR}/edm-cics/sql" ]; then
    if [ -z "$(ls -A "/${ZFS_POOL}/users/edm-sql" 2>/dev/null)" ]; then
        echo "==> Populating edm-sql from submodule..."
        cp -r "${SCRIPT_DIR}/edm-cics/sql/."               "/${ZFS_POOL}/users/edm-sql/"
    fi
fi

# Create named Podman volumes bound to ZFS datasets
echo "==> Creating Podman volumes..."
for vol_ds in     "edm-pgdata:/${ZFS_POOL}/containers/edm-postgres"     "edm-bricks-data:/${ZFS_POOL}/containers/edm-bricks"     "edm-runtime:/${ZFS_POOL}/users/edm-runtime"     "edm-sql:/${ZFS_POOL}/users/edm-sql"; do
    vol="$(echo "${vol_ds}" | cut -d: -f1)"
    dev="$(echo "${vol_ds}" | cut -d: -f2)"
    if podman volume inspect "${vol}" >/dev/null 2>&1; then
        echo "    exists: ${vol}"
    else
        podman volume create             --opt type=none             --opt o=bind             --opt device="${dev}"             "${vol}"
        echo "    created: ${vol} -> ${dev}"
    fi
done

# Pull BRICKS image
echo "==> Pulling ghcr.io/denzuko/bricks_ts:latest..."
podman pull ghcr.io/denzuko/bricks_ts:latest ||     echo "WARNING: pull failed — run manually before starting"

echo ""
echo "==> Done. Run:"
echo "    systemctl --user daemon-reload"
echo "    systemctl --user start edm-cics.target"
echo ""
echo "    web3270 (plain):   http://localhost:9000"
echo "    web3270 (TLS):     https://your-host:443  (via HAProxy)"
echo "    3270 TLS:          your-host:2323          (via HAProxy)"
echo ""
echo "    See haproxy/edm.cfg for TLS termination config."
