# edm-cics-quadlet
## Ellison Digital Minerals CICS Stack — Podman Quadlet Deployment

Rootless Podman Quadlet units for running the EDM CICS transaction
processing environment: BRICKS_TS + PostgreSQL.

Submodules:
- `bricks/` — [denzuko/BRICKS_TS-docker](https://github.com/denzuko/BRICKS_TS-docker)
- `edm-cics/` — [denzuko/edm-cics](https://github.com/denzuko/edm-cics) (COBOL/REXX source, SQL DDL)

## Prerequisites

- Podman >= 4.4 (Quadlet support)
- systemd user session (`loginctl enable-linger $USER`)

## Quick start

```sh
git clone --recurse-submodules https://github.com/denzuko/edm-cics-quadlet
cd edm-cics-quadlet
./install.sh
systemctl --user daemon-reload
systemctl --user start edm-cics.target
```

Connect via web3270: http://localhost:9000

Or with any 3270 emulator on port 2300:
```sh
c3270 -port 2300 localhost
```

## Units

| Unit | Type | Purpose |
|------|------|---------|
| `edm-postgres.container` | Container | PostgreSQL 16 (official image) |
| `edm-bricks.container` | Container | BRICKS_TS transaction server |
| `edm-cics.network` | Network | Internal pod network |
| `edm-cics.target` | Target | Brings up the full stack |
| `edm-pgdata.volume` | Volume | Postgres data persistence |

## Environment overrides

Copy `.env.example` to `.env` and set:

```sh
POSTGRES_PASSWORD=change_this_in_production
BRICKS_enforce_secure_login=yes
```

## License

BSD-2-Clause.
