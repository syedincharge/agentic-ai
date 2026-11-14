-- Resets the Notebook 4 teaching data. Times are relative to now, so the scenarios stay valid.
TRUNCATE zp_payouts, zp_refunds, zp_ticket_events, zp_tickets, zp_reviewers,
         zp_order_items, zp_orders, zp_restaurants, zp_customers RESTART IDENTITY CASCADE;

INSERT INTO zp_customers (customer_id, name, email, phone, tier, city, joined_at, fraud_flag) VALUES
    (1,  'Asha Verma',    'asha.verma@example.com',    '+91 98100 11111', 'REGULAR', 'Bengaluru', NOW() - INTERVAL '400 days', FALSE),
    (2,  'Rohan Iyer',    'rohan.iyer@example.com',    '+91 98100 22222', 'PLUS',    'Mumbai',    NOW() - INTERVAL '300 days', FALSE),
    (3,  'Priya Menon',   'priya.menon@example.com',   '+91 98100 33333', 'PRO',     'Chennai',   NOW() - INTERVAL '700 days', FALSE),
    (4,  'Vikram Singh',  'vikram.singh@example.com',  '+91 98100 44444', 'REGULAR', 'Delhi',     NOW() - INTERVAL '200 days', FALSE),
    (5,  'Neha Kapoor',   'neha.kapoor@example.com',   '+91 98100 55555', 'REGULAR', 'Pune',      NOW() - INTERVAL '90 days',  FALSE),
    (6,  'Imran Qureshi', 'imran.qureshi@example.com', '+91 98100 66666', 'PLUS',    'Hyderabad', NOW() - INTERVAL '500 days', FALSE),
    (7,  'Sana Reddy',    'sana.reddy@example.com',    '+91 98100 77777', 'PRO',     'Hyderabad', NOW() - INTERVAL '800 days', FALSE),
    (8,  'Arjun Das',     'arjun.das@example.com',     '+91 98100 88888', 'REGULAR', 'Kolkata',   NOW() - INTERVAL '150 days', FALSE),
    (9,  'Meera Joshi',   'meera.joshi@example.com',   '+91 98100 99999', 'REGULAR', 'Mumbai',    NOW() - INTERVAL '60 days',  FALSE),
    (10, 'Kabir Malhotra','kabir.m@example.com',       '+91 98100 10101', 'REGULAR', 'Delhi',     NOW() - INTERVAL '30 days',  FALSE),
    (11, 'Tara Nair',     'tara.nair@example.com',     '+91 98100 12121', 'PLUS',    'Kochi',     NOW() - INTERVAL '250 days', FALSE),
    (12, 'Dev Patel',     'dev.patel@example.com',     '+91 98100 13131', 'REGULAR', 'Ahmedabad', NOW() - INTERVAL '5 days',   TRUE);

INSERT INTO zp_restaurants (restaurant_id, name, city, cuisine, avg_prep_minutes, rating) VALUES
    (1, 'Biryani Blues',       'Bengaluru', 'Hyderabadi', 25, 4.3),
    (2, 'Punjab Grill House',  'Mumbai',    'North Indian', 30, 4.1),
    (3, 'Dosa Corner',         'Chennai',   'South Indian', 15, 4.5),
    (4, 'Pizza Pronto',        'Delhi',     'Italian',    22, 3.9),
    (5, 'Wok This Way',        'Pune',      'Chinese',    20, 4.0),
    (6, 'Kebab Kingdom',       'Hyderabad', 'Mughlai',    28, 4.4);

-- Scenario orders. delay = delivered_at - promised_at.
INSERT INTO zp_orders (order_id, customer_id, restaurant_id, status, subtotal, delivery_fee, total, payment_method, payment_status, placed_at, promised_at, delivered_at) VALUES
    -- ZP-1001: 45 minutes late, small order -> automatic refund
    ('ZP-1001', 1, 1, 'DELIVERED', 440, 40, 480, 'UPI',  'CAPTURED', NOW() - INTERVAL '5 hours',  NOW() - INTERVAL '4 hours 15 minutes', NOW() - INTERVAL '3 hours 30 minutes'),
    -- ZP-1002: 75 minutes late, larger order -> reviewer
    ('ZP-1002', 1, 2, 'DELIVERED', 1160, 40, 1200, 'CARD', 'CAPTURED', NOW() - INTERVAL '6 hours',  NOW() - INTERVAL '5 hours 15 minutes', NOW() - INTERVAL '4 hours'),
    -- ZP-1003: only 20 minutes late -> not eligible
    ('ZP-1003', 2, 3, 'DELIVERED', 310, 40, 350, 'UPI',  'CAPTURED', NOW() - INTERVAL '4 hours',  NOW() - INTERVAL '3 hours 20 minutes', NOW() - INTERVAL '3 hours'),
    -- ZP-1004: a missing item scenario (garlic naan x2)
    ('ZP-1004', 3, 2, 'DELIVERED', 600, 40, 640, 'UPI',  'CAPTURED', NOW() - INTERVAL '3 hours',  NOW() - INTERVAL '2 hours 15 minutes', NOW() - INTERVAL '2 hours 10 minutes'),
    -- ZP-1005: cancelled by the restaurant after payment
    ('ZP-1005', 4, 4, 'CANCELLED_BY_RESTAURANT', 520, 40, 560, 'CARD', 'CAPTURED', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 hour 20 minutes', NULL),
    -- ZP-1006: customer with many recent refunds, 40 minutes late
    ('ZP-1006', 5, 5, 'DELIVERED', 660, 40, 700, 'UPI',  'CAPTURED', NOW() - INTERVAL '5 hours',  NOW() - INTERVAL '4 hours 20 minutes', NOW() - INTERVAL '3 hours 40 minutes'),
    -- ZP-1007: on its way (order status question)
    ('ZP-1007', 6, 6, 'OUT_FOR_DELIVERY', 780, 40, 820, 'UPI', 'CAPTURED', NOW() - INTERVAL '35 minutes', NOW() + INTERVAL '10 minutes', NULL),
    -- ZP-1008: PRO customer, 90 minutes late, big order
    ('ZP-1008', 7, 6, 'DELIVERED', 2360, 40, 2400, 'CARD', 'CAPTURED', NOW() - INTERVAL '6 hours', NOW() - INTERVAL '5 hours', NOW() - INTERVAL '3 hours 30 minutes'),
    -- ZP-1009: late, but delivered 5 days ago -> outside the 48 hour window
    ('ZP-1009', 8, 1, 'DELIVERED', 560, 40, 600, 'UPI',  'CAPTURED', NOW() - INTERVAL '5 days',   NOW() - INTERVAL '4 days 23 hours', NOW() - INTERVAL '4 days 21 hours 40 minutes'),
    -- ZP-1010: just placed (cancellation / address questions)
    ('ZP-1010', 9, 3, 'PLACED', 260, 40, 300, 'WALLET', 'CAPTURED', NOW() - INTERVAL '5 minutes', NOW() + INTERVAL '35 minutes', NULL),
    -- ZP-1011: very large order, 100 minutes late -> senior (high value)
    ('ZP-1011', 10, 2, 'DELIVERED', 3560, 40, 3600, 'CARD', 'CAPTURED', NOW() - INTERVAL '7 hours', NOW() - INTERVAL '6 hours', NOW() - INTERVAL '4 hours 20 minutes'),
    -- ZP-1012: a quality complaint scenario (butter chicken)
    ('ZP-1012', 2, 2, 'DELIVERED', 710, 40, 750, 'UPI',  'CAPTURED', NOW() - INTERVAL '3 hours',  NOW() - INTERVAL '2 hours 20 minutes', NOW() - INTERVAL '2 hours 25 minutes'),
    -- ZP-1013: older, normal order for customer 1
    ('ZP-1013', 1, 3, 'DELIVERED', 260, 40, 300, 'UPI',  'CAPTURED', NOW() - INTERVAL '10 days',  NOW() - INTERVAL '9 days 23 hours', NOW() - INTERVAL '9 days 23 hours'),
    -- ZP-1014: customer 11, on-time delivery (no basis for a refund)
    ('ZP-1014', 11, 5, 'DELIVERED', 460, 40, 500, 'UPI', 'CAPTURED', NOW() - INTERVAL '2 hours',  NOW() - INTERVAL '1 hour 20 minutes', NOW() - INTERVAL '1 hour 30 minutes'),
    -- ZP-1015: flagged new account, 50 minutes late
    ('ZP-1015', 12, 4, 'DELIVERED', 360, 40, 400, 'COD', 'NOT_APPLICABLE', NOW() - INTERVAL '4 hours', NOW() - INTERVAL '3 hours 20 minutes', NOW() - INTERVAL '2 hours 30 minutes');

INSERT INTO zp_order_items (order_id, item_name, quantity, unit_price) VALUES
    ('ZP-1001', 'Chicken Biryani', 1, 320), ('ZP-1001', 'Raita', 1, 40), ('ZP-1001', 'Gulab Jamun', 2, 40),
    ('ZP-1002', 'Butter Chicken', 2, 380), ('ZP-1002', 'Dal Makhani', 1, 260), ('ZP-1002', 'Butter Naan', 4, 35),
    ('ZP-1003', 'Masala Dosa', 2, 110), ('ZP-1003', 'Filter Coffee', 2, 45),
    ('ZP-1004', 'Paneer Tikka Masala', 1, 380), ('ZP-1004', 'Garlic Naan', 2, 60), ('ZP-1004', 'Jeera Rice', 1, 100),
    ('ZP-1005', 'Margherita Pizza', 2, 260),
    ('ZP-1006', 'Veg Hakka Noodles', 2, 200), ('ZP-1006', 'Manchurian', 2, 130),
    ('ZP-1007', 'Mutton Seekh Kebab', 2, 390),
    ('ZP-1008', 'Galouti Kebab', 4, 350), ('ZP-1008', 'Chicken Dum Biryani', 3, 320),
    ('ZP-1009', 'Chicken Biryani', 1, 320), ('ZP-1009', 'Chicken 65', 1, 240),
    ('ZP-1010', 'Plain Dosa', 2, 90), ('ZP-1010', 'Idli', 2, 40),
    ('ZP-1011', 'Tandoori Platter', 4, 640), ('ZP-1011', 'Dal Makhani', 3, 260), ('ZP-1011', 'Butter Naan', 4, 55),
    ('ZP-1012', 'Butter Chicken', 1, 350), ('ZP-1012', 'Butter Naan', 4, 35), ('ZP-1012', 'Jeera Rice', 1, 100), ('ZP-1012', 'Mango Lassi', 2, 60),
    ('ZP-1013', 'Masala Dosa', 2, 110), ('ZP-1013', 'Filter Coffee', 1, 40),
    ('ZP-1014', 'Chilli Chicken', 1, 280), ('ZP-1014', 'Fried Rice', 1, 180),
    ('ZP-1015', 'Pepperoni Pizza', 1, 360);

INSERT INTO zp_reviewers (reviewer_id, name, role, active) VALUES
    ('rev-asha',  'Asha Reviewer',  'REVIEWER', TRUE),
    ('rev-ravi',  'Ravi Reviewer',  'REVIEWER', TRUE),
    ('sen-iqbal', 'Iqbal Senior',   'SENIOR',   TRUE),
    ('rev-old',   'Former Reviewer','REVIEWER', FALSE);

-- Refund history that the fraud check reads. Customer 5 has four recent refunds; customer 1 has one.
INSERT INTO zp_refunds (ticket_id, order_id, customer_id, reason_code, amount, approval_level, status, decided_by, decided_at, idempotency_key, created_at) VALUES
    ('HIST-1', 'ZP-1013', 1, 'LATE', 60, 'AUTO', 'APPROVED', 'system:auto', NOW() - INTERVAL '20 days', 'hist-1', NOW() - INTERVAL '20 days');
INSERT INTO zp_orders (order_id, customer_id, restaurant_id, status, subtotal, delivery_fee, total, payment_method, payment_status, placed_at, promised_at, delivered_at) VALUES
    ('ZP-0901', 5, 5, 'DELIVERED', 300, 40, 340, 'UPI', 'REFUNDED', NOW() - INTERVAL '25 days', NOW() - INTERVAL '25 days', NOW() - INTERVAL '25 days'),
    ('ZP-0902', 5, 5, 'DELIVERED', 300, 40, 340, 'UPI', 'REFUNDED', NOW() - INTERVAL '18 days', NOW() - INTERVAL '18 days', NOW() - INTERVAL '18 days'),
    ('ZP-0903', 5, 5, 'DELIVERED', 300, 40, 340, 'UPI', 'REFUNDED', NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days'),
    ('ZP-0904', 5, 5, 'DELIVERED', 300, 40, 340, 'UPI', 'REFUNDED', NOW() - INTERVAL '4 days',  NOW() - INTERVAL '4 days',  NOW() - INTERVAL '4 days');
INSERT INTO zp_refunds (ticket_id, order_id, customer_id, reason_code, amount, approval_level, status, decided_by, decided_at, idempotency_key, created_at) VALUES
    ('HIST-2', 'ZP-0901', 5, 'LATE', 85, 'AUTO', 'APPROVED', 'system:auto', NOW() - INTERVAL '25 days', 'hist-2', NOW() - INTERVAL '25 days'),
    ('HIST-3', 'ZP-0902', 5, 'MISSING_ITEM', 120, 'AUTO', 'APPROVED', 'system:auto', NOW() - INTERVAL '18 days', 'hist-3', NOW() - INTERVAL '18 days'),
    ('HIST-4', 'ZP-0903', 5, 'LATE', 85, 'AUTO', 'APPROVED', 'system:auto', NOW() - INTERVAL '10 days', 'hist-4', NOW() - INTERVAL '10 days'),
    ('HIST-5', 'ZP-0904', 5, 'QUALITY', 150, 'REVIEWER', 'APPROVED', 'rev-asha', NOW() - INTERVAL '4 days', 'hist-5', NOW() - INTERVAL '4 days');

-- The historical refunds were paid out long ago.
INSERT INTO zp_payouts (refund_id, amount, method)
    SELECT r.refund_id, r.amount, o.payment_method FROM zp_refunds r JOIN zp_orders o USING (order_id) WHERE r.status = 'APPROVED';
