import os
import time

import psycopg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.environ["DATABASE_URL"]


def ok(**data):
    result = {"ok": True}
    result.update(data)
    return result


def fail(code, message, **data):
    result = {"ok": False, "code": code, "message": message}
    result.update(data)
    return result




# A switch we can flip later to simulate a database outage
SIMULATE_DB_FAILURE = False


def get_connection():
    if SIMULATE_DB_FAILURE:
        raise psycopg.OperationalError("simulated outage")

    return psycopg.connect(
        DATABASE_URL,
        connect_timeout=5,
        options="-c statement_timeout=5000",
    )


def run_with_retry(function, *args, attempts=3, pause=0.5):
    for attempt in range(1, attempts + 1):
        try:
            return function(*args)
        except psycopg.OperationalError as error:
            # OperationalError = connection problems and timeouts, often temporary
            print(f"   [log] attempt {attempt}/{attempts} failed: {type(error).__name__}")
            if attempt == attempts:
                raise
            time.sleep(pause * attempt)   # wait a little longer each time


def order_from_row(row):
    order = {
        "order_id": row[0],
        "restaurant": row[1],
        "items": row[2],
        "status": row[3],
        "total_amount": float(row[4]),
        "created_at": str(row[5]),
        "promised_at": str(row[6]) if row[6] else None,
        "delivered_at": str(row[7]) if row[7] else None,
        "minutes_late": None,
    }
    if row[6] and row[7]:
        order["minutes_late"] = round((row[7] - row[6]).total_seconds() / 60)
    return order


ORDER_COLUMNS = "order_id, restaurant, items, status, total_amount, created_at, promised_at, delivered_at"


def query_latest_order(customer_id):
    with get_connection() as conn:
        row = conn.execute(
            f"SELECT {ORDER_COLUMNS} FROM orders WHERE customer_id = %s ORDER BY created_at DESC LIMIT 1",
            (customer_id,),
        ).fetchone()
    return row


def query_order(customer_id, order_id):
    with get_connection() as conn:
        row = conn.execute(
            f"SELECT {ORDER_COLUMNS} FROM orders WHERE order_id = %s AND customer_id = %s",
            (order_id, customer_id),
        ).fetchone()
    return row


def check_refund_allowed(customer_id, order_id, amount):
    with get_connection() as conn:
        # 1. Does this order exist AND belong to this customer?
        order = conn.execute(
            "SELECT status, total_amount FROM orders WHERE order_id = %s AND customer_id = %s",
            (order_id, customer_id),
        ).fetchone()

    if order is None:
        return fail("ORDER_NOT_FOUND", "No matching order was found.")

    # 2. Business rules
    if order[0] != "DELIVERED":
        return fail("ORDER_NOT_DELIVERED", "Only delivered orders can be refunded.")

    if amount > float(order[1]):
        return fail("AMOUNT_TOO_HIGH", "The amount is higher than the order total.")

    return None


def create_refund_request(customer_id, order_id, amount, reason):
    problem = check_refund_allowed(customer_id, order_id, amount)
    if problem is not None:
        return problem

    key = f"refund:{customer_id}:{order_id}"

    with get_connection() as conn:
        row = conn.execute(
            """
            INSERT INTO refund_requests (order_id, customer_id, amount, reason, idempotency_key)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (idempotency_key) DO NOTHING
            RETURNING id, status
            """,
            (order_id, customer_id, amount, reason, key),
        ).fetchone()

        if row is not None:
            return ok(
                code="REFUND_REQUESTED",
                refund_request_id=row[0],
                status=row[1],
                message="Refund request created and waiting for human review. No money has been refunded yet.",
            )

        # Duplicate: report what already exists
        existing = conn.execute(
            "SELECT id, status FROM refund_requests WHERE idempotency_key = %s", (key,)
        ).fetchone()

    return fail(
        "ALREADY_REQUESTED",
        "A refund request already exists for this order.",
        refund_request_id=existing[0],
        status=existing[1],
    )


def get_or_create_thread(customer_id, name):
    thread_id = f"customer-{customer_id}-{name}"
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO conversation_threads (thread_id, customer_id) VALUES (%s, %s) ON CONFLICT (thread_id) DO NOTHING",
            (thread_id, customer_id),
        )
    return thread_id


def thread_belongs_to(customer_id, thread_id):
    with get_connection() as conn:
        row = conn.execute(
            "SELECT 1 FROM conversation_threads WHERE thread_id = %s AND customer_id = %s",
            (thread_id, customer_id),
        ).fetchone()
    return row is not None


ALLOWED_PREFERENCES = {
    "contact_method": ["email", "sms", "phone"],
    "language": ["english", "hindi"],
}


def save_preference(customer_id, key, value):
    if key not in ALLOWED_PREFERENCES:
        return fail("INVALID_PREFERENCE", "That preference cannot be saved.")
    if value not in ALLOWED_PREFERENCES[key]:
        return fail("INVALID_VALUE", "Allowed values: " + ", ".join(ALLOWED_PREFERENCES[key]))

    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO customer_preferences (customer_id, preference_key, preference_value)
            VALUES (%s, %s, %s)
            ON CONFLICT (customer_id, preference_key)
            DO UPDATE SET preference_value = EXCLUDED.preference_value, updated_at = NOW()
            """,
            (customer_id, key, value),
        )
    return ok(message="Preference saved.")


def read_preferences(customer_id):
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT preference_key, preference_value FROM customer_preferences WHERE customer_id = %s",
            (customer_id,),
        ).fetchall()
    return {row[0]: row[1] for row in rows}


def get_refund_request(refund_id):
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id, order_id, customer_id, amount, reason, status FROM refund_requests WHERE id = %s",
            (refund_id,),
        ).fetchone()

    if row is None:
        return None
    return {
        "id": row[0], "order_id": row[1], "customer_id": row[2],
        "amount": float(row[3]), "reason": row[4], "status": row[5],
    }


def decide_refund(refund_id, approved, reviewer_id, note):
    new_status = "APPROVED" if approved else "REJECTED"

    with get_connection() as conn:
        # Only a PENDING request can be decided. This is the idempotency guard.
        row = conn.execute(
            """
            UPDATE refund_requests
            SET status = %s, decided_by = %s, decision_note = %s, decided_at = NOW()
            WHERE id = %s AND status = 'PENDING'
            RETURNING id
            """,
            (new_status, reviewer_id, note, refund_id),
        ).fetchone()

        if row is not None:
            return ok(code="DECISION_RECORDED", status=new_status)

        existing = conn.execute(
            "SELECT status FROM refund_requests WHERE id = %s", (refund_id,)
        ).fetchone()

    if existing is None:
        return fail("NOT_FOUND", "No such refund request.")
    return fail("ALREADY_DECIDED", "This request was already decided.", status=existing[0])
