-- Production-style support workflow (Notebook 4). Tables use the zp_ prefix so Notebooks 1 to 3 are not affected.
-- Safe to run again (IF NOT EXISTS). Checkpoint tables are created by LangGraph.

CREATE TABLE IF NOT EXISTS zp_customers (
    customer_id  INTEGER PRIMARY KEY,
    name         TEXT NOT NULL,
    email        TEXT NOT NULL,
    phone        TEXT NOT NULL,
    tier         TEXT NOT NULL CHECK (tier IN ('REGULAR', 'PLUS', 'PRO')),
    city         TEXT NOT NULL,
    joined_at    TIMESTAMPTZ NOT NULL,
    fraud_flag   BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS zp_restaurants (
    restaurant_id     INTEGER PRIMARY KEY,
    name              TEXT NOT NULL,
    city              TEXT NOT NULL,
    cuisine           TEXT NOT NULL,
    avg_prep_minutes  INTEGER NOT NULL,
    rating            NUMERIC(2, 1) NOT NULL
);

CREATE TABLE IF NOT EXISTS zp_orders (
    order_id        TEXT PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES zp_customers(customer_id),
    restaurant_id   INTEGER NOT NULL REFERENCES zp_restaurants(restaurant_id),
    status          TEXT NOT NULL CHECK (status IN
                    ('PLACED', 'PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED',
                     'CANCELLED_BY_RESTAURANT', 'CANCELLED_BY_CUSTOMER')),
    subtotal        NUMERIC(10, 2) NOT NULL,
    delivery_fee    NUMERIC(10, 2) NOT NULL,
    total           NUMERIC(10, 2) NOT NULL,
    payment_method  TEXT NOT NULL CHECK (payment_method IN ('UPI', 'CARD', 'COD', 'WALLET')),
    payment_status  TEXT NOT NULL CHECK (payment_status IN ('CAPTURED', 'PENDING', 'REFUNDED', 'NOT_APPLICABLE')),
    placed_at       TIMESTAMPTZ NOT NULL,
    promised_at     TIMESTAMPTZ NOT NULL,
    delivered_at    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS zp_orders_customer_idx ON zp_orders (customer_id, placed_at DESC);

CREATE TABLE IF NOT EXISTS zp_order_items (
    id          BIGSERIAL PRIMARY KEY,
    order_id    TEXT NOT NULL REFERENCES zp_orders(order_id),
    item_name   TEXT NOT NULL,
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(10, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS zp_reviewers (
    reviewer_id  TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    role         TEXT NOT NULL CHECK (role IN ('REVIEWER', 'SENIOR')),
    active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS zp_tickets (
    ticket_id         TEXT PRIMARY KEY,
    customer_id       INTEGER NOT NULL,
    thread_id         TEXT NOT NULL,
    message_redacted  TEXT NOT NULL,
    intent            TEXT,
    status            TEXT NOT NULL DEFAULT 'OPEN'
                      CHECK (status IN ('OPEN', 'AWAITING_APPROVAL', 'RESOLVED', 'HANDED_OFF')),
    outcome           TEXT,
    route             TEXT,
    prompt_version    TEXT,
    trace_id          TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at         TIMESTAMPTZ
);

-- Audit trail: one row per workflow step. Written at the end of a run, from workflow state.
CREATE TABLE IF NOT EXISTS zp_ticket_events (
    id          BIGSERIAL PRIMARY KEY,
    ticket_id   TEXT NOT NULL,
    seq         INTEGER NOT NULL,
    step        TEXT NOT NULL,
    detail      JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (ticket_id, seq)
);

CREATE TABLE IF NOT EXISTS zp_refunds (
    refund_id        BIGSERIAL PRIMARY KEY,
    ticket_id        TEXT NOT NULL,
    order_id         TEXT NOT NULL REFERENCES zp_orders(order_id),
    customer_id      INTEGER NOT NULL,
    reason_code      TEXT NOT NULL CHECK (reason_code IN ('LATE', 'MISSING_ITEM', 'QUALITY', 'NOT_DELIVERED', 'OTHER')),
    amount           NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    approval_level   TEXT NOT NULL CHECK (approval_level IN ('AUTO', 'REVIEWER', 'SENIOR')),
    status           TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED')),
    review_deadline  TIMESTAMPTZ,
    decided_by       TEXT,
    decision_note    TEXT,
    decided_at       TIMESTAMPTZ,
    idempotency_key  TEXT NOT NULL UNIQUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- At most one live refund per order and reason, even across different tickets.
CREATE UNIQUE INDEX IF NOT EXISTS zp_refunds_one_live
    ON zp_refunds (order_id, reason_code) WHERE status IN ('PENDING', 'APPROVED');

-- The money-moving side effect. UNIQUE (refund_id) guarantees a refund is paid out at most once.
CREATE TABLE IF NOT EXISTS zp_payouts (
    payout_id   BIGSERIAL PRIMARY KEY,
    refund_id   BIGINT NOT NULL UNIQUE REFERENCES zp_refunds(refund_id),
    amount      NUMERIC(10, 2) NOT NULL,
    method      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
