-- =====================================================================
-- Zomato DBMS Project — Phase 2: Data Ingestion Script
-- File: sql/02_load_data.sql
-- Description: Ingests all 11 seed CSV datasets into PostgreSQL
-- Database: PostgreSQL 15+
-- Authors: Team T0002 (Piyush Tharwani, Anubhav Jaiswal, Aadarsh, Prince Goswami)
-- =====================================================================

SET search_path TO zomato;

-- 1. Cities (Parent table for localities, customers, delivery partners)
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true);

-- 2. Localities (Depends on cities; parent for restaurants)
\copy localities FROM 'seed_data/localities.csv' WITH (FORMAT csv, HEADER true);

-- 3. Customers (Depends on cities; parent for orders, reviews)
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true);

-- 4. Delivery Partners (Depends on cities; referenced by orders)
\copy delivery_partners FROM 'seed_data/delivery_partners.csv' WITH (FORMAT csv, HEADER true);

-- 5. Coupons (Referenced by orders)
\copy coupons FROM 'seed_data/coupons.csv' WITH (FORMAT csv, HEADER true);

-- 6. Restaurants (Depends on localities; parent for menu_items, orders, reviews)
\copy restaurants FROM 'seed_data/restaurants.csv' WITH (FORMAT csv, HEADER true);

-- 7. Menu Items (Depends on restaurants; parent for order_items)
\copy menu_items FROM 'seed_data/menu_items.csv' WITH (FORMAT csv, HEADER true);

-- 8. Orders (Depends on customers, restaurants, delivery_partners, coupons; parent for order_items, payments, reviews)
\copy orders FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true);

-- 9. Order Items (Depends on orders, menu_items)
\copy order_items FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true);

-- 10. Payments (Depends on orders)
\copy payments FROM 'seed_data/payments.csv' WITH (FORMAT csv, HEADER true);

-- 11. Reviews (Depends on orders, customers, restaurants)
\copy reviews FROM 'seed_data/reviews.csv' WITH (FORMAT csv, HEADER true);

-- Update PostgreSQL query planner statistics
ANALYZE;

-- Quick verification of row counts
SELECT 'cities' AS table_name, count(*) AS row_count FROM cities
UNION ALL SELECT 'localities', count(*) FROM localities
UNION ALL SELECT 'customers', count(*) FROM customers
UNION ALL SELECT 'delivery_partners', count(*) FROM delivery_partners
UNION ALL SELECT 'coupons', count(*) FROM coupons
UNION ALL SELECT 'restaurants', count(*) FROM restaurants
UNION ALL SELECT 'menu_items', count(*) FROM menu_items
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'payments', count(*) FROM payments
UNION ALL SELECT 'reviews', count(*) FROM reviews;
