CREATE TABLE IF NOT EXISTS customers (
    customer_id BIGINT PRIMARY KEY,
    name        TEXT NOT NULL,
    email       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
    order_id     TEXT PRIMARY KEY,
    customer_id  BIGINT NOT NULL REFERENCES customers (customer_id),
    restaurant   TEXT NOT NULL,
    items        TEXT NOT NULL,
    status       TEXT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    promised_at  TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS refund_requests (
    id              BIGSERIAL PRIMARY KEY,
    order_id        TEXT NOT NULL REFERENCES orders (order_id),
    customer_id     BIGINT NOT NULL,
    amount          NUMERIC(10, 2) NOT NULL,
    reason          TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'PENDING',
    idempotency_key TEXT NOT NULL UNIQUE,
    decided_by      TEXT,
    decision_note   TEXT,
    decided_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS customer_preferences (
    customer_id      BIGINT NOT NULL,
    preference_key   TEXT NOT NULL,
    preference_value TEXT NOT NULL,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (customer_id, preference_key)
);

CREATE TABLE IF NOT EXISTS conversation_threads (
    thread_id   TEXT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
