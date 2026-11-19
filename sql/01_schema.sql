-- =====================================================================
-- Zomato DBMS Project — Phase 2: Schema Definition
-- File: sql/01_schema.sql
-- Description: Baseline relational schema for Zomato Food Delivery
-- Database: PostgreSQL 15+
-- Authors: Team T0002 (Piyush Tharwani, Anubhav Jaiswal, Aadarsh, Prince Goswami)
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS zomato;
SET search_path TO zomato;

-- Clean teardown of existing tables in dependency order
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS menu_items CASCADE;
DROP TABLE IF EXISTS restaurants CASCADE;
DROP TABLE IF EXISTS coupons CASCADE;
DROP TABLE IF EXISTS delivery_partners CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS localities CASCADE;
DROP TABLE IF EXISTS cities CASCADE;

-- ---------------------------------------------------------------------
-- 1. CITIES
-- ---------------------------------------------------------------------
CREATE TABLE cities (
    city_id     INT PRIMARY KEY,
    city_name   VARCHAR(50) NOT NULL UNIQUE,
    state       VARCHAR(50) NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. LOCALITIES
-- ---------------------------------------------------------------------
CREATE TABLE localities (
    locality_id   INT PRIMARY KEY,
    city_id       INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    locality_name VARCHAR(100) NOT NULL,
    pincode       VARCHAR(10) NOT NULL,
    CONSTRAINT uq_locality_city_name UNIQUE (city_id, locality_name)
);

-- ---------------------------------------------------------------------
-- 3. CUSTOMERS
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id     INT PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    phone           VARCHAR(20) NOT NULL UNIQUE,
    city_id         INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    signup_date     DATE NOT NULL,
    is_gold_member  BOOLEAN NOT NULL DEFAULT FALSE,
    gold_expires_on DATE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_customer_gold_expiry CHECK (is_gold_member = FALSE OR gold_expires_on IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- 4. DELIVERY PARTNERS
-- ---------------------------------------------------------------------
CREATE TABLE delivery_partners (
    partner_id    INT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    phone         VARCHAR(20) NOT NULL UNIQUE,
    city_id       INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    vehicle_type  VARCHAR(20) NOT NULL,
    joined_on     DATE NOT NULL,
    rating        NUMERIC(2,1) NOT NULL,
    status        VARCHAR(20) NOT NULL,
    CONSTRAINT chk_dp_vehicle CHECK (vehicle_type IN ('BIKE', 'SCOOTER', 'EV', 'BICYCLE')),
    CONSTRAINT chk_dp_rating CHECK (rating >= 1.0 AND rating <= 5.0),
    CONSTRAINT chk_dp_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'BLOCKED'))
);

-- ---------------------------------------------------------------------
-- 5. COUPONS
-- ---------------------------------------------------------------------
CREATE TABLE coupons (
    coupon_code     VARCHAR(50) PRIMARY KEY,
    discount_pct    NUMERIC(5,2) NOT NULL,
    max_discount    NUMERIC(10,2) NOT NULL,
    min_order_value NUMERIC(10,2) NOT NULL,
    valid_from      DATE NOT NULL,
    valid_to        DATE NOT NULL,
    CONSTRAINT chk_coupon_discount_pct CHECK (discount_pct > 0 AND discount_pct <= 100),
    CONSTRAINT chk_coupon_max_discount CHECK (max_discount > 0),
    CONSTRAINT chk_coupon_min_order CHECK (min_order_value >= 0),
    CONSTRAINT chk_coupon_valid_dates CHECK (valid_to >= valid_from)
);

-- ---------------------------------------------------------------------
-- 6. RESTAURANTS
-- ---------------------------------------------------------------------
CREATE TABLE restaurants (
    restaurant_id    INT PRIMARY KEY,
    name             VARCHAR(150) NOT NULL,
    locality_id      INT NOT NULL REFERENCES localities(locality_id) ON DELETE RESTRICT,
    cuisines         TEXT[] NOT NULL,
    avg_cost_for_two NUMERIC(10,2) NOT NULL,
    rating           NUMERIC(2,1),
    rating_count     INT NOT NULL DEFAULT 0,
    opens_at         TIME NOT NULL,
    closes_at        TIME NOT NULL,
    is_pure_veg      BOOLEAN NOT NULL DEFAULT FALSE,
    status           VARCHAR(30) NOT NULL,
    onboarded_on     DATE NOT NULL,
    CONSTRAINT chk_restaurant_avg_cost CHECK (avg_cost_for_two > 0),
    CONSTRAINT chk_restaurant_rating CHECK (rating IS NULL OR (rating >= 1.0 AND rating <= 5.0)),
    CONSTRAINT chk_restaurant_rating_count CHECK (rating_count >= 0),
    CONSTRAINT chk_restaurant_status CHECK (status IN ('OPEN', 'TEMPORARILY_CLOSED', 'DELISTED'))
);

-- ---------------------------------------------------------------------
-- 7. MENU ITEMS
-- ---------------------------------------------------------------------
CREATE TABLE menu_items (
    item_id       INT PRIMARY KEY,
    restaurant_id INT NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    item_name     VARCHAR(150) NOT NULL,
    category      VARCHAR(50) NOT NULL,
    price         NUMERIC(10,2) NOT NULL,
    is_veg        BOOLEAN NOT NULL DEFAULT FALSE,
    is_bestseller BOOLEAN NOT NULL DEFAULT FALSE,
    is_available  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_menu_category CHECK (category IN ('Starters', 'Main Course', 'Rice', 'Breads', 'Desserts', 'Beverages')),
    CONSTRAINT chk_menu_price CHECK (price >= 0)
);

-- ---------------------------------------------------------------------
-- 8. ORDERS
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id      BIGINT PRIMARY KEY,
    customer_id   INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    restaurant_id INT NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE RESTRICT,
    partner_id    INT REFERENCES delivery_partners(partner_id) ON DELETE SET NULL,
    coupon_code   VARCHAR(50) REFERENCES coupons(coupon_code) ON DELETE SET NULL,
    placed_at     TIMESTAMPTZ NOT NULL,
    accepted_at   TIMESTAMPTZ,
    picked_up_at  TIMESTAMPTZ,
    delivered_at  TIMESTAMPTZ,
    distance_km   NUMERIC(5,2) NOT NULL,
    item_total    NUMERIC(10,2) NOT NULL,
    delivery_fee  NUMERIC(10,2) NOT NULL,
    discount      NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    total_amount  NUMERIC(10,2) NOT NULL,
    status        VARCHAR(30) NOT NULL,
    CONSTRAINT chk_order_distance CHECK (distance_km >= 0),
    CONSTRAINT chk_order_item_total CHECK (item_total >= 0),
    CONSTRAINT chk_order_delivery_fee CHECK (delivery_fee >= 0),
    CONSTRAINT chk_order_discount CHECK (discount >= 0),
    CONSTRAINT chk_order_total_amount CHECK (total_amount >= 0),
    CONSTRAINT chk_order_status CHECK (status IN ('PLACED', 'ACCEPTED', 'PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED_BY_CUSTOMER', 'CANCELLED_BY_RESTAURANT')),
    CONSTRAINT chk_order_total_calc CHECK (total_amount = (item_total + delivery_fee - discount)),
    CONSTRAINT chk_order_accepted_temporal CHECK (accepted_at IS NULL OR accepted_at >= placed_at),
    CONSTRAINT chk_order_pickup_temporal CHECK (picked_up_at IS NULL OR (accepted_at IS NOT NULL AND picked_up_at >= accepted_at)),
    CONSTRAINT chk_order_delivery_temporal CHECK (delivered_at IS NULL OR (picked_up_at IS NOT NULL AND delivered_at >= picked_up_at))
);

-- ---------------------------------------------------------------------
-- 9. ORDER ITEMS
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id   BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    item_id    INT NOT NULL REFERENCES menu_items(item_id) ON DELETE RESTRICT,
    quantity   INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, item_id),
    CONSTRAINT chk_order_items_qty CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price CHECK (unit_price >= 0)
);

-- ---------------------------------------------------------------------
-- 10. PAYMENTS
-- ---------------------------------------------------------------------
CREATE TABLE payments (
    payment_id     INT PRIMARY KEY,
    order_id       BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    amount         NUMERIC(10,2) NOT NULL,
    method         VARCHAR(20) NOT NULL,
    payment_status VARCHAR(20) NOT NULL,
    attempted_at   TIMESTAMPTZ NOT NULL,
    CONSTRAINT chk_payment_amount CHECK (amount >= 0),
    CONSTRAINT chk_payment_method CHECK (method IN ('CARD', 'UPI', 'COD', 'WALLET')),
    CONSTRAINT chk_payment_status CHECK (payment_status IN ('SUCCESS', 'REFUNDED', 'FAILED'))
);

-- ---------------------------------------------------------------------
-- 11. REVIEWS
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    review_id       INT PRIMARY KEY,
    order_id        BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    customer_id     INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    restaurant_id   INT NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE RESTRICT,
    food_rating     SMALLINT NOT NULL,
    delivery_rating SMALLINT,
    review_text     TEXT,
    created_at      TIMESTAMPTZ NOT NULL,
    CONSTRAINT chk_review_food_rating CHECK (food_rating >= 1 AND food_rating <= 5),
    CONSTRAINT chk_review_delivery_rating CHECK (delivery_rating IS NULL OR (delivery_rating >= 1 AND delivery_rating <= 5))
);
