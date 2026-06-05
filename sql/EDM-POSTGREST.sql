-- EDM-POSTGREST.sql -- PostgREST role and permission setup
-- Creates the web_anon and web_user roles used by PostgREST.
-- web_anon: unauthenticated read access to community-safe views
-- web_user: authenticated access for webhooks (BMAC, etc.)
-- Run after EDM-DDL.sql against the edm database.

BEGIN;

-- Create roles if not present
DO $$ BEGIN
    CREATE ROLE web_anon  NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE ROLE web_user  NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Grant web roles to the bricks user so PostgREST can switch
GRANT web_anon TO bricks;
GRANT web_user TO bricks;

-- ── Public read views (community forum / BBS pattern, issue #5) ──────
-- These views expose non-sensitive data for unauthenticated access.

-- Public show schedule (DPR)
CREATE OR REPLACE VIEW public_shows AS
    SELECT show_id, show_name, day_of_week, start_time,
           duration_mins, description, stream_url
    FROM   dpr_shows
    WHERE  status = 'A';

GRANT SELECT ON public_shows TO web_anon;

-- Public helpdesk status (no client data exposed)
CREATE OR REPLACE VIEW public_tickets AS
    SELECT ticket_id, opened_at, status, priority,
           category, subject
    FROM   edm_tickets
    WHERE  status NOT IN ('C');  -- hide closed tickets

GRANT SELECT ON public_tickets TO web_anon;

-- ── Authenticated webhook endpoints (BMAC, issue #10) ────────────────
-- web_user can INSERT into webhook_events; a trigger fans out to
-- the appropriate EDM subsystem tables.

CREATE TABLE IF NOT EXISTS webhook_events (
    event_id        BIGSERIAL       PRIMARY KEY,
    received_at     TIMESTAMP       NOT NULL DEFAULT NOW(),
    source          VARCHAR(20)     NOT NULL,
    -- BMAC, STRIPE, GITHUB, etc.
    event_type      VARCHAR(40)     NOT NULL,
    payload         JSONB           NOT NULL,
    processed       BOOLEAN         NOT NULL DEFAULT FALSE,
    error_detail    VARCHAR(254)    NOT NULL DEFAULT ''
);

GRANT INSERT ON webhook_events TO web_user;
GRANT USAGE, SELECT ON SEQUENCE webhook_events_event_id_seq TO web_user;

-- Trigger: fan BMAC supporter webhooks into edm_clients
CREATE OR REPLACE FUNCTION process_webhook_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_supporter_email TEXT;
    v_supporter_name  TEXT;
    v_client_id       CHAR(8);
BEGIN
    IF NEW.source = 'BMAC' AND NEW.event_type = 'new_supporter' THEN
        v_supporter_email := NEW.payload->>'supporter_email';
        v_supporter_name  := NEW.payload->>'supporter_name';

        -- Derive client_id from email (first 8 chars, uppercased)
        v_client_id := RPAD(UPPER(LEFT(
            REGEXP_REPLACE(v_supporter_email,'[^a-zA-Z0-9]','','g'), 8
        )), 8);

        INSERT INTO edm_clients
            (client_id, client_type, risk_tier, last_name, first_name,
             location, status, created_date, reserved1)
        VALUES
            (v_client_id, 'C', 3,
             COALESCE(SPLIT_PART(v_supporter_name,' ',2), v_supporter_name),
             SPLIT_PART(v_supporter_name,' ',1),
             'RMT', 'A', CURRENT_DATE, v_supporter_email)
        ON CONFLICT (client_id) DO UPDATE
            SET status       = 'A',
                last_activity = CURRENT_DATE,
                reserved1     = v_supporter_email;

        UPDATE webhook_events SET processed = TRUE WHERE event_id = NEW.event_id;
    END IF;

    PERFORM pg_notify('webhook_received', NEW.event_id::TEXT);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_webhook_process ON webhook_events;
CREATE TRIGGER trg_webhook_process
    AFTER INSERT ON webhook_events
    FOR EACH ROW EXECUTE FUNCTION process_webhook_event();

COMMIT;
