# CLAUDE.md — edm-cics-quadlet

## Project

Podman Quadlet deployment for the EDM CICS stack. Rootless Podman,
ZFS volumes (`storage/containers/<name>`), two tenants: EDM (MSSP/business
ops) and DPR (Da Planet Radio back-office). HAProxy for reverse proxying only.

Application source lives in `edm-cics` (sibling repo, included as submodule).

## Architecture

```
quadlet/          — systemd .container/.network/.volume unit files
haproxy/          — HAProxy configuration
bricks/           — BRICKS_TS integration layer
sql/              — deployment-time SQL (schema apply, seed)
install.sh        — bootstrap installer
compose.yml       — development compose (not production)
kubernetes/       — k8s manifests (reference only, not active)
```

## net.matrix labels

All `.container` Quadlet unit files carry `Label=net.matrix.*` keys.
All Containerfiles carry `LABEL net.matrix.*` directives.
These are the deployment-layer expression of the identity baked into
the application binaries in `edm-cics`.

## Workflow (BDD-first)

1. Open GitHub Issue
2. Branch: `feat/N` or `fix/N`
3. Write BATS test in `tests/qa.bats` first
4. Write Quadlet/shell until tests pass
5. Update `CHANGELOG.md`
6. Push → PR → review → merge → semver tag

## Semver

- MAJOR — breaking Quadlet interface or volume layout change
- MINOR — new non-breaking service or tenant
- PATCH — everything else

## Standards

- BSD 2-Clause Licence
- POSIX sh only for `install.sh` — no bash-isms
- net.matrix labels in all Quadlet `.container` units and Containerfiles
- SLSA Level 3 provenance on release tarballs
- No Nginx, no new orchestration platforms — HAProxy only
- No Airflow, Celery, Redis in this stack
