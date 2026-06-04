#!/bin/sh
# install.sh -- install Quadlet units for current user
set -e

QUADLET_DIR="${HOME}/.config/containers/systemd"
ENV_DIR="${HOME}/.config/containers"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing EDM CICS Quadlet units..."

mkdir -p "${QUADLET_DIR}" "${ENV_DIR}"

# Copy unit files
for f in "${SCRIPT_DIR}/quadlet/"*; do
    cp "$f" "${QUADLET_DIR}/"
    echo "    installed: $(basename $f)"
done

# Install env file if not already present
if [ ! -f "${ENV_DIR}/edm.env" ]; then
    cp "${SCRIPT_DIR}/.env.example" "${ENV_DIR}/edm.env"
    echo "    installed: edm.env (edit ${ENV_DIR}/edm.env to set passwords)"
else
    echo "    skipped: edm.env already exists"
fi

# Build the BRICKS image from submodule
echo "==> Building BRICKS_TS image..."
podman build -t localhost/bricks:latest "${SCRIPT_DIR}/bricks/" || {
    echo "WARNING: podman build failed -- pull image manually or fix Dockerfile"
}

echo ""
echo "==> Done. Run:"
echo "    systemctl --user daemon-reload"
echo "    systemctl --user start edm-cics.target"
echo ""
echo "    web3270:  http://localhost:9000"
echo "    3270 TCP: c3270 -port 2300 localhost"
echo ""
echo "    Edit ${ENV_DIR}/edm.env to set POSTGRES_PASSWORD before starting."
