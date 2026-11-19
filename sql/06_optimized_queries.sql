-- =====================================================================
-- Zomato DBMS Project: optimized versions of the 30 benchmark queries
--   R01–R25 : read queries  (25)
--   W01–W05 : write queries (5)
-- =====================================================================
SET search_path TO zomato;
BEGIN;

-- @R01
-- Home feed: open restaurants in Koramangala, best rated first
-- No rewrite: the partial locality/rating index handles the filter and ordering.
SELECT r.restaurant_id, r.name, r.cuisines, r.avg_cost_for_two, r.rating
FROM restaurants r
JOIN localities l ON l.locality_id = r.locality_id
WHERE l.locality_name = 'Koramangala'
  AND r.status = 'OPEN'
ORDER BY r.rating DESC NULLS LAST
LIMIT 20;

-- @R02
-- Dish search: available "paneer" dishes in Bengaluru
-- No rewrite: the available-item trigram index targets the substring predicate.
SELECT m.item_id, m.item_name, m.price, r.name AS restaurant
FROM menu_items m
JOIN restaurants r ON r.restaurant_id = m.restaurant_id
JOIN localities l  ON l.locality_id   = r.locality_id
WHERE l.city_id = 1
  AND m.is_available
  AND m.item_name ILIKE '%paneer%'
ORDER BY m.price
LIMIT 50;

-- @R03
-- Restaurant page: the menu of one restaurant, grouped by category
-- No rewrite: the partial menu index matches the restaurant, availability, and display order.
SELECT category, item_name, price, is_veg, is_bestseller
FROM menu_items
WHERE restaurant_id = 217 AND is_available
ORDER BY category, is_bestseller DESC, item_name;

-- @R04
-- "Your orders": a customer's last 10 orders with restaurant names
-- No rewrite: the customer/placed_at index supports the ordered top-10 lookup.
SELECT o.order_id, r.name AS restaurant, o.status, o.total_amount, o.placed_at
FROM orders o
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
WHERE o.customer_id = 1042
ORDER BY o.placed_at DESC
LIMIT 10;

-- @R05
-- Kitchen-delay alert: orders stuck in PREPARING for over 40 minutes (checked at 23:59 on 30 Jun 2026)
-- No rewrite: the partial PREPARING index supports the accepted_at range.
SELECT order_id, restaurant_id, accepted_at
FROM orders
WHERE status = 'PREPARING'
  AND accepted_at < TIMESTAMPTZ '2026-06-30 23:59:00+05:30' - interval '40 minutes'
ORDER BY accepted_at;

-- @R06
-- Restaurant partner app: all orders received by restaurant 217 on 15 June 2026
-- Replaced DATE(placed_at) with a half-open range so idx_orders_restaurant_id_placed_at is usable.
SELECT order_id, status, item_total, placed_at
FROM orders
WHERE restaurant_id = 217
  AND placed_at >= DATE '2026-06-15'
  AND placed_at < DATE '2026-06-16'
ORDER BY placed_at;

-- @R07
-- Restaurant partner app: units sold per dish in May 2026
-- No rewrite: the restaurant/placed_at index supports the selective order range.
SELECT m.item_name, sum(oi.quantity) AS units, sum(oi.quantity * oi.unit_price) AS sales
FROM order_items oi
JOIN orders o     ON o.order_id = oi.order_id
JOIN menu_items m ON m.item_id  = oi.item_id
WHERE o.restaurant_id = 217
  AND o.status = 'DELIVERED'
  AND o.placed_at >= '2026-05-01' AND o.placed_at < '2026-06-01'
GROUP BY m.item_name
ORDER BY units DESC;

-- @R08
-- Bestseller badges: top 3 dishes of every Pune restaurant in the last 30 days
-- No rewrite: the partial delivered/time index reduces the qualifying order scan.
SELECT *
FROM (
    SELECT o.restaurant_id, oi.item_id, sum(oi.quantity) AS units,
           RANK() OVER (PARTITION BY o.restaurant_id ORDER BY sum(oi.quantity) DESC) AS rnk
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN restaurants r  ON r.restaurant_id = o.restaurant_id
    JOIN localities l   ON l.locality_id = r.locality_id
    WHERE l.city_id = 6
      AND o.status = 'DELIVERED'
      AND o.placed_at >= '2026-06-01'
    GROUP BY o.restaurant_id, oi.item_id
) t
WHERE rnk <= 3
ORDER BY restaurant_id, rnk;

-- @R09
-- Ops dashboard: average delivery time (minutes) per city per month in 2026
-- Replaced EXTRACT(YEAR) with a half-open date range for idx_orders_delivered_placed_at.
SELECT l.city_id, date_trunc('month', o.placed_at) AS month,
       round(avg(EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) / 60), 1) AS avg_minutes
FROM orders o
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
JOIN localities l  ON l.locality_id   = r.locality_id
WHERE o.status = 'DELIVERED'
  AND o.placed_at >= TIMESTAMPTZ '2026-01-01 00:00:00'
  AND o.placed_at < TIMESTAMPTZ '2027-01-01 00:00:00'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R10
-- Customer support: deliveries in June 2026 that took more than 60 minutes
-- No rewrite: the placed_at index supports the June range; the duration filter remains unchanged.
SELECT order_id, customer_id, restaurant_id, placed_at, delivered_at
FROM orders
WHERE delivered_at - placed_at > interval '60 minutes'
  AND placed_at >= '2026-06-01' AND placed_at < '2026-07-01'
ORDER BY delivered_at - placed_at DESC
LIMIT 100;

-- @R11
-- Delivery partner app: this week's earnings (delivery fees) for partner 150
-- No rewrite: the partner/placed_at index supports the lookup; delivered status is checked on matching rows.
SELECT count(*) AS deliveries, sum(delivery_fee) AS fees_earned
FROM orders
WHERE partner_id = 150
  AND status = 'DELIVERED'
  AND placed_at >= '2026-06-22' AND placed_at < '2026-06-29';

-- @R12
-- Dispatch: orders still waiting for a delivery partner, oldest first
-- No rewrite: the partial unassigned-order index supplies the oldest qualifying rows.
SELECT o.order_id, o.restaurant_id, o.status, o.placed_at
FROM orders o
WHERE o.partner_id IS NULL
  AND o.status IN ('PLACED', 'ACCEPTED')
ORDER BY o.placed_at
LIMIT 50;

-- @R13
-- Fleet team: active Bengaluru partners who have not been assigned any order since 25 June 2026
-- RESULT CHANGE (bug fix): NOT IN returned no rows if any recent order had a NULL partner_id; NOT EXISTS correctly tests assignments to each partner.
-- Uses idx_orders_partner_id_placed_at for the correlated partner/time probe.
SELECT p.partner_id, p.full_name, p.phone
FROM delivery_partners p
WHERE p.city_id = 1
  AND p.status = 'ACTIVE'
  AND NOT EXISTS (
      SELECT 1
      FROM orders o
      WHERE o.partner_id = p.partner_id
        AND o.placed_at >= '2026-06-25'
  );

-- @R14
-- Gold team: Gold members whose membership expires before July 2026 but who ordered in June 2026
-- No rewrite: the customer/placed_at index supports the correlated June existence check.
SELECT c.customer_id, c.full_name, c.gold_expires_on
FROM customers c
WHERE c.is_gold_member
  AND c.gold_expires_on < '2026-07-01'
  AND EXISTS (SELECT 1 FROM orders o
              WHERE o.customer_id = c.customer_id
                AND o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01');

-- @R15
-- Marketing: coupon effectiveness (orders, total discount, average bill)
-- No rewrite: the partial delivered-coupon index supports the outer join.
SELECT c.coupon_code, c.discount_pct, count(o.order_id) AS orders,
       coalesce(sum(o.discount), 0) AS total_discount, round(avg(o.total_amount), 2) AS avg_bill
FROM coupons c
LEFT JOIN orders o ON o.coupon_code = c.coupon_code AND o.status = 'DELIVERED'
GROUP BY c.coupon_code, c.discount_pct
ORDER BY orders DESC;

-- @R16
-- Payments team: failed payment attempts per method in the last 7 days
-- No rewrite: the payment status/time index narrows recent failed attempts.
SELECT method, count(*) AS failed_attempts
FROM payments
WHERE payment_status = 'FAILED'
  AND attempted_at >= '2026-06-24'
GROUP BY method
ORDER BY failed_attempts DESC;

-- @R17
-- Risk team: customers with 2 or more failed payment attempts (all time)
-- No rewrite: the payment status index covers order_id for the customer aggregation join.
SELECT o.customer_id, count(*) AS failed_attempts
FROM payments p
JOIN orders o ON o.order_id = p.order_id
WHERE p.payment_status = 'FAILED'
GROUP BY o.customer_id
HAVING count(*) >= 2
ORDER BY failed_attempts DESC, o.customer_id;

-- @R18
-- Review moderation: newest reviews that complain about cold food or late delivery
-- No rewrite: the trigram GIN index supports both substring predicates.
SELECT review_id, restaurant_id, food_rating, review_text, created_at
FROM reviews
WHERE review_text ILIKE '%cold%' OR review_text ILIKE '%late%'
ORDER BY created_at DESC
LIMIT 50;

-- @R19
-- Restaurant health report for Bengaluru: last order time, delivered orders and average food rating
-- Combines two correlated order scans into one lateral aggregate using idx_orders_restaurant_id_placed_at and idx_reviews_restaurant_id.
SELECT r.restaurant_id, r.name,
       os.last_order_at,
       os.delivered_orders,
       rs.avg_food_rating
FROM restaurants r
JOIN localities l ON l.locality_id = r.locality_id
LEFT JOIN LATERAL (
    SELECT max(o.placed_at) AS last_order_at,
           count(*) FILTER (WHERE o.status = 'DELIVERED') AS delivered_orders
    FROM orders o
    WHERE o.restaurant_id = r.restaurant_id
) os ON TRUE
LEFT JOIN LATERAL (
    SELECT round(avg(v.food_rating), 2) AS avg_food_rating
    FROM reviews v
    WHERE v.restaurant_id = r.restaurant_id
) rs ON TRUE
WHERE l.city_id = 1
ORDER BY os.last_order_at DESC NULLS LAST;

-- @R20
-- Growth: top 20 customers in Mumbai by total spend on delivered orders
-- No rewrite: the city index narrows customers, and the customer/placed_at index supports order lookup.
SELECT c.customer_id, c.full_name, count(*) AS orders, sum(o.total_amount) AS lifetime_spend
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE c.city_id = 2 AND o.status = 'DELIVERED'
GROUP BY c.customer_id, c.full_name
ORDER BY lifetime_spend DESC
LIMIT 20;

-- @R21
-- Growth: share of customers in each city who ordered at least twice in May 2026
-- No rewrite: the placed_at/customer_id index supports the date range and customer grouping.
WITH may AS (
    SELECT customer_id, count(*) AS n
    FROM orders
    WHERE placed_at >= '2026-05-01' AND placed_at < '2026-06-01'
    GROUP BY customer_id
)
SELECT c.city_id,
       count(*) AS ordering_customers,
       count(*) FILTER (WHERE may.n >= 2) AS repeat_customers,
       round(100.0 * count(*) FILTER (WHERE may.n >= 2) / count(*), 1) AS repeat_pct
FROM may
JOIN customers c ON c.customer_id = may.customer_id
GROUP BY c.city_id
ORDER BY c.city_id;

-- @R22
-- Ops heatmap: Bengaluru orders by weekday and hour, last 8 weeks
-- No rewrite: the placed_at/customer_id index supports the time lower bound.
SELECT EXTRACT(ISODOW FROM o.placed_at) AS weekday, EXTRACT(HOUR FROM o.placed_at) AS hour, count(*) AS orders
FROM orders o
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
JOIN localities l  ON l.locality_id = r.locality_id
WHERE l.city_id = 1
  AND o.placed_at >= TIMESTAMPTZ '2026-07-01 00:00:00+05:30' - interval '8 weeks'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R23
-- Admin panel: "All orders", newest first, page 4,001 (25 rows per page)
-- No rewrite: the placed_at index provides newest-first order without a full sort.
SELECT order_id, customer_id, restaurant_id, status, total_amount, placed_at
FROM orders
ORDER BY placed_at DESC
OFFSET 100000
LIMIT 25;

-- @R24
-- Bill page: one order with its items, restaurant and successful payment
-- No rewrite: the primary-key lookup plus partial successful-payment index supports the joins.
SELECT o.order_id, o.placed_at, r.name AS restaurant, m.item_name, oi.quantity, oi.unit_price,
       o.total_amount, p.method
FROM orders o
JOIN restaurants r  ON r.restaurant_id = o.restaurant_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN menu_items m   ON m.item_id = oi.item_id
LEFT JOIN payments p ON p.order_id = o.order_id AND p.payment_status = 'SUCCESS'
WHERE o.order_id = 123457;

-- @R25
-- Cuisine filter: open Chinese restaurants in Pune
-- Replaced array ANY with equivalent containment so idx_restaurants_cuisines is usable.
SELECT r.restaurant_id, r.name, r.cuisines, r.rating
FROM restaurants r
JOIN localities l ON l.locality_id = r.locality_id
WHERE l.city_id = 6
  AND r.status = 'OPEN'
  AND r.cuisines @> ARRAY['Chinese']
ORDER BY r.rating DESC NULLS LAST;

-- @W01
-- Customer app: place a new order (header row)
-- No rewrite: preserves the exact insert effect.
INSERT INTO orders (order_id, customer_id, restaurant_id, placed_at, distance_km,
                    item_total, delivery_fee, discount, total_amount, status)
VALUES (90000001, 1042, 217, '2026-07-01 13:05:00+05:30', 3.2, 540.00, 25.00, 0.00, 565.00, 'PLACED');

-- @W02
-- Dispatch: assign partner 150 to the oldest accepted order that has no partner
-- No rewrite: preserves the exact update effect.
UPDATE orders
SET partner_id = 150, status = 'PREPARING'
WHERE order_id = (SELECT order_id FROM orders
                  WHERE partner_id IS NULL AND status = 'ACCEPTED'
                  ORDER BY placed_at
                  LIMIT 1);

-- @W03
-- Restaurant partner app: desserts sold out, so hide them
-- No rewrite: preserves the exact update effect.
UPDATE menu_items
SET is_available = FALSE
WHERE restaurant_id = 217 AND category = 'Desserts';

-- @W04
-- Nightly job: recompute every restaurant's rating from its reviews
-- No rewrite: preserves the exact update effect.
UPDATE restaurants r
SET rating = s.avg_rating, rating_count = s.n
FROM (SELECT restaurant_id, round(avg(food_rating), 1) AS avg_rating, count(*) AS n
      FROM reviews GROUP BY restaurant_id) s
WHERE s.restaurant_id = r.restaurant_id;

-- @W05
-- Nightly job: end Gold membership for customers whose plan has expired
-- No rewrite: preserves the exact update effect.
UPDATE customers
SET is_gold_member = FALSE
WHERE is_gold_member
  AND gold_expires_on < '2026-07-01';

-- @END
ROLLBACK;
