SET search_path TO zomato;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
SET search_path TO zomato, public;

-- R01: avoids filtering/sorting all open restaurants for the requested locality.
CREATE INDEX idx_restaurants_locality_id_rating
    ON restaurants (locality_id, rating DESC NULLS LAST)
    INCLUDE (name, cuisines, avg_cost_for_two)
    WHERE status = 'OPEN';

-- R02: trigram search avoids scanning every available menu item for substring matches.
CREATE INDEX idx_menu_items_item_name_trgm
    ON menu_items USING GIN (item_name gin_trgm_ops)
    WHERE is_available;

-- R03: filters and returns a restaurant's available menu in the requested display order.
CREATE INDEX idx_menu_items_restaurant_id_category
    ON menu_items (restaurant_id, category, is_bestseller DESC, item_name)
    INCLUDE (price, is_veg)
    WHERE is_available;

-- R25: array containment is GIN-indexable; partial predicate excludes closed restaurants.
CREATE INDEX idx_restaurants_cuisines
    ON restaurants USING GIN (cuisines)
    WHERE status = 'OPEN';

-- R04, R14: customer equality followed by placed_at supports recent-order lookup and existence checks.
CREATE INDEX idx_orders_customer_id_placed_at
    ON orders (customer_id, placed_at DESC);

-- R05: partial index finds old PREPARING orders without scanning all statuses.
CREATE INDEX idx_orders_preparing_accepted_at
    ON orders (accepted_at)
    WHERE status = 'PREPARING';

-- R06, R07, R19: restaurant equality followed by time supports date ranges and the R19 order aggregate.
CREATE INDEX idx_orders_restaurant_id_placed_at
    ON orders (restaurant_id, placed_at DESC)
    INCLUDE (status);

-- R08, R09: restricts time-range scans to delivered orders; restaurant_id supports grouping/join work.
CREATE INDEX idx_orders_delivered_placed_at
    ON orders (placed_at, restaurant_id)
    WHERE status = 'DELIVERED';

-- R11, R13: partner equality followed by time supports partner/date lookups and anti-join probes.
CREATE INDEX idx_orders_partner_id_placed_at
    ON orders (partner_id, placed_at)
    WHERE partner_id IS NOT NULL;

-- R12, W02: oldest unassigned orders are ordered directly from a small partial index.
CREATE INDEX idx_orders_unassigned_placed_at
    ON orders (placed_at)
    INCLUDE (order_id, restaurant_id, status)
    WHERE partner_id IS NULL AND status IN ('PLACED', 'ACCEPTED');

-- R10, R21, R22, R23: time-range scans, May grouping, and newest-first pagination use placed_at order.
CREATE INDEX idx_orders_placed_at_customer_id
    ON orders (placed_at, customer_id);

-- R15: the join only needs delivered orders for each coupon.
CREATE INDEX idx_orders_delivered_coupon_code
    ON orders (coupon_code)
    WHERE status = 'DELIVERED';

-- R16, R17: narrows failed attempts by status/time and covers method/order_id aggregation and joins.
CREATE INDEX idx_payments_status_attempted_at
    ON payments (payment_status, attempted_at)
    INCLUDE (method, order_id);

-- R18: trigram index accelerates both substring predicates in review_text.
CREATE INDEX idx_reviews_review_text_trgm
    ON reviews USING GIN (review_text gin_trgm_ops);

-- R19: supports per-restaurant review aggregates with an index-only path where visibility permits.
CREATE INDEX idx_reviews_restaurant_id
    ON reviews (restaurant_id)
    INCLUDE (food_rating);

-- R20: filters the customer side to Mumbai before aggregating delivered orders.
CREATE INDEX idx_customers_city_id
    ON customers (city_id);

-- R24: finds successful payments for the selected order without scanning other attempts.
CREATE INDEX idx_payments_success_order_id
    ON payments (order_id)
    INCLUDE (method)
    WHERE payment_status = 'SUCCESS';

ANALYZE;
