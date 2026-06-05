#!/usr/bin/env bats
# qa.bats -- QA assertions for EDM CICS Quadlet deployment
# Run: bats tests/qa.bats
# Requires: podman, systemd user session, stack already started

setup() {
    # Skip all if stack is not running
    podman ps --filter name=edm-postgres --format '{{.Status}}' \
        | grep -q 'Up' || skip "edm-postgres not running"
}

@test "edm-postgres container is running" {
    run podman ps --filter name=edm-postgres --format '{{.Status}}'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Up" ]]
}

@test "edm-bricks container is running" {
    run podman ps --filter name=edm-bricks --format '{{.Status}}'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Up" ]]
}

@test "edm-postgres healthcheck is healthy" {
    run podman healthcheck run edm-postgres
    [ "$status" -eq 0 ]
}

@test "BRICKS_TS 3270 port 2300 is listening" {
    run podman exec edm-bricks sh -c         'ss -tlnp | grep :2300 || netstat -tlnp | grep :2300'
    [ "$status" -eq 0 ]
}

@test "BRICKS_TS web3270 port 9000 is listening" {
    run podman exec edm-bricks sh -c         'ss -tlnp | grep :9000 || netstat -tlnp | grep :9000'
    [ "$status" -eq 0 ]
}

@test "edm-cics network exists" {
    run podman network inspect edm-cics
    [ "$status" -eq 0 ]
}

@test "edm-pgdata volume is mounted" {
    run podman volume inspect edm-pgdata
    [ "$status" -eq 0 ]
}

@test "edm-bricks-data volume is mounted" {
    run podman volume inspect edm-bricks-data
    [ "$status" -eq 0 ]
}

@test "ZFS dataset storage/containers/edm-postgres exists" {
    run zfs list storage/containers/edm-postgres
    [ "$status" -eq 0 ]
}

@test "ZFS dataset storage/containers/edm-bricks exists" {
    run zfs list storage/containers/edm-bricks
    [ "$status" -eq 0 ]
}

@test "ZFS dataset storage/users/edm-runtime exists" {
    run zfs list storage/users/edm-runtime
    [ "$status" -eq 0 ]
}

@test "ZFS dataset storage/users/edm-sql exists" {
    run zfs list storage/users/edm-sql
    [ "$status" -eq 0 ]
}

@test "transactions.conf is present in runtime volume" {
    run podman exec edm-bricks test -f /srv/bricks/runtime/transactions.conf
    [ "$status" -eq 0 ]
}

@test "EDM-DDL.sql is present in sql volume" {
    run podman exec edm-bricks test -f /srv/bricks/sql/EDM-DDL.sql
    [ "$status" -eq 0 ]
}

@test "edm_clients table exists in PostgreSQL" {
    run podman exec edm-postgres psql -U bricks -d bricks -tAc \
        "SELECT 1 FROM information_schema.tables WHERE table_name='edm_clients'"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "edm_audit table has UPDATE revoked" {
    run podman exec edm-postgres psql -U bricks -d bricks -tAc \
        "SELECT has_table_privilege('bricks','edm_audit','UPDATE')"
    [ "$status" -eq 0 ]
    [ "$output" = "f" ]
}

@test "edm-postgrest container is running" {
    run podman ps --filter name=edm-postgrest --format '{{.Status}}'
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Up" ]]
}

@test "PostgREST API responds on port 3000" {
    run curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
    [ "$status" -eq 0 ]
    [ "$output" = "200" ]
}

@test "public_shows view is readable without auth" {
    run curl -s -o /dev/null -w "%{http_code}"         http://localhost:3000/public_shows
    [ "$status" -eq 0 ]
    [ "$output" = "200" ]
}

@test "print_queue table exists" {
    run podman exec edm-postgres psql -U bricks -d edm -tAc         "SELECT 1 FROM information_schema.tables WHERE table_name='print_queue'"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "webhook_events table exists" {
    run podman exec edm-postgres psql -U bricks -d edm -tAc         "SELECT 1 FROM information_schema.tables WHERE table_name='webhook_events'"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "rpt_client_list() function exists" {
    run podman exec edm-postgres psql -U bricks -d edm -tAc         "SELECT COUNT(*) FROM pg_proc WHERE proname='rpt_client_list'"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "process_print_queue() function exists" {
    run podman exec edm-postgres psql -U bricks -d edm -tAc         "SELECT COUNT(*) FROM pg_proc WHERE proname='process_print_queue'"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}
