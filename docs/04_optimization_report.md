# CP3 · Optimization report

## Summary

For the 30-query workload, the sum of the per-query three-run averages decreased from **4,548.799 ms to 145.719 ms**, a **96.80%** decrease. This is a sum of averages across separate queries, not the duration of one end-to-end application request. R19 contributed the largest reduction: **4,278.454 ms**.

Baseline and optimized runs were performed on Anubhav’s MacBook Pro, using the same local seed database, `zomato_cp2_baseline`, and PostgreSQL 18.7 (Postgres.app), as required for a fair before/after comparison. Each query was run three times. Write workload statements ran in transactions that were rolled back. The machine-specific measurements should not be treated as universal performance guarantees.

## Before and after

“Plan scans” summarizes the scan nodes recorded in each run’s benchmark summary. A scan-node change helps explain the result, but does not by itself prove that the index caused the entire timing difference; cache state and run-to-run variation also matter. Percent change is `(before − after) / before × 100`; negative values mean slower after optimization.

| Query | Type | Before avg (ms) | After avg (ms) | Change | Baseline scan nodes | Optimized scan nodes |
|---|---|---:|---:|---:|---|---|
| R01 | READ | 0.279 | 0.215 | +22.94% | Seq Scan on restaurants; Seq Scan on localities | Seq Scan on localities; Bitmap Heap Scan on restaurants; Bitmap Index Scan on idx_restaurants_locality_id_rating |
| R02 | READ | 19.243 | 5.497 | +71.43% | Seq Scan on menu_items; Seq Scan on restaurants; Seq Scan on localities | Seq Scan on restaurants; Seq Scan on localities; Index Scan using idx_menu_items_restaurant_id_category on menu_items |
| R03 | READ | 1.905 | 0.058 | +96.96% | Seq Scan on menu_items | Index Only Scan using idx_menu_items_restaurant_id_category on menu_items |
| R04 | READ | 4.804 | 0.498 | +89.63% | Seq Scan on orders; Index Scan using restaurants_pkey on restaurants | Bitmap Heap Scan on orders; Bitmap Index Scan on idx_orders_customer_id_placed_at; Index Scan using restaurants_pkey on restaurants |
| R05 | READ | 6.409 | 0.163 | +97.46% | Seq Scan on orders | Index Scan using idx_orders_preparing_accepted_at on orders |
| R06 | READ | 4.821 | 0.206 | +95.73% | Seq Scan on orders | Index Scan using idx_orders_restaurant_id_placed_at on orders |
| R07 | READ | 5.820 | 0.322 | +94.47% | Seq Scan on orders; Index Scan using order_items_pkey on order_items; Index Scan using menu_items_pkey on menu_items | Bitmap Heap Scan on orders; Bitmap Index Scan on idx_orders_restaurant_id_placed_at; Index Scan using order_items_pkey on order_items; Index Scan using menu_items_pkey on menu_items |
| R08 | READ | 6.364 | 5.660 | +11.06% | Seq Scan on orders; Seq Scan on restaurants; Seq Scan on localities; Index Scan using order_items_pkey on order_items | Seq Scan on restaurants; Seq Scan on localities; Index Scan using idx_orders_restaurant_id_placed_at on orders; Index Scan using order_items_pkey on order_items |
| R09 | READ | 22.551 | 21.516 | +4.59% | Seq Scan on orders; Seq Scan on restaurants; Seq Scan on localities | Bitmap Heap Scan on orders; Bitmap Index Scan on idx_orders_delivered_placed_at; Seq Scan on restaurants; Seq Scan on localities |
| R10 | READ | 7.135 | 1.130 | +84.16% | Seq Scan on orders | Bitmap Heap Scan on orders; Bitmap Index Scan on idx_orders_placed_at_customer_id |
| R11 | READ | 6.641 | 0.319 | +95.20% | Seq Scan on orders | Index Scan using idx_orders_partner_id_placed_at on orders |
| R12 | READ | 7.253 | 0.183 | +97.48% | Seq Scan on orders | Index Only Scan using idx_orders_unassigned_placed_at on orders |
| R13 | READ | 6.051 | 2.462 | +59.31% | Seq Scan on delivery_partners; Seq Scan on orders | Seq Scan on delivery_partners; Index Only Scan using idx_orders_partner_id_placed_at on orders |
| R14 | READ | 6.799 | 2.135 | +68.60% | Seq Scan on orders; Seq Scan on customers | Index Only Scan using idx_orders_placed_at_customer_id on orders; Seq Scan on customers |
| R15 | READ | 13.762 | 7.067 | +48.65% | Seq Scan on orders; Seq Scan on coupons | Index Scan using coupons_pkey on coupons; Index Scan using idx_orders_delivered_coupon_code on orders |
| R16 | READ | 3.944 | 0.170 | +95.69% | Seq Scan on payments | Index Only Scan using idx_payments_status_attempted_at on payments |
| R17 | READ | 14.988 | 11.775 | +21.44% | Seq Scan on orders; Seq Scan on payments | Seq Scan on orders; Index Only Scan using idx_payments_status_attempted_at on payments |
| R18 | READ | 11.855 | 2.345 | +80.22% | Seq Scan on reviews | Bitmap Heap Scan on reviews; Bitmap Index Scan on idx_reviews_review_text_trgm |
| R19 | READ | 4285.167 | 6.713 | +99.84% | Seq Scan on restaurants; Seq Scan on localities; Seq Scan on orders; Seq Scan on reviews | Seq Scan on restaurants; Seq Scan on localities; Index Only Scan using idx_orders_restaurant_id_placed_at on orders; Index Only Scan using idx_reviews_restaurant_id on reviews |
| R20 | READ | 19.542 | 18.061 | +7.58% | Seq Scan on orders; Seq Scan on customers | Seq Scan on orders; Bitmap Heap Scan on customers; Bitmap Index Scan on idx_customers_city_id |
| R21 | READ | 9.710 | 4.684 | +51.76% | Seq Scan on customers; Seq Scan on orders | Seq Scan on customers; Index Only Scan using idx_orders_placed_at_customer_id on orders |
| R22 | READ | 13.304 | 2.217 | +83.34% | Seq Scan on orders; Seq Scan on restaurants; Seq Scan on localities | Seq Scan on restaurants; Seq Scan on localities; Index Only Scan using idx_orders_restaurant_id_placed_at on orders |
| R23 | READ | 36.493 | 11.361 | +68.87% | Seq Scan on orders | Index Scan using idx_orders_placed_at_customer_id on orders |
| R24 | READ | 5.135 | 0.346 | +93.26% | Index Scan using orders_pkey on orders; Index Scan using restaurants_pkey on restaurants; Seq Scan on payments; Index Scan using order_items_pkey on order_items; Index Scan using menu_items_pkey on menu_items | Index Scan using orders_pkey on orders; Index Scan using restaurants_pkey on restaurants; Index Only Scan using idx_payments_success_order_id on payments; Index Scan using order_items_pkey on order_items; Index Scan using menu_items_pkey on menu_items |
| R25 | READ | 0.312 | 0.170 | +45.51% | Seq Scan on restaurants; Seq Scan on localities | Bitmap Heap Scan on restaurants; Bitmap Index Scan on idx_restaurants_cuisines; Seq Scan on localities |
| W01 | WRITE | 0.674 | 0.995 | -47.63% | (no scan) | (no scan) |
| W02 | WRITE | 8.789 | 0.629 | +92.84% | Seq Scan on orders; Index Scan using orders_pkey on orders | Index Only Scan using idx_orders_unassigned_placed_at on orders; Index Scan using orders_pkey on orders |
| W03 | WRITE | 1.631 | 1.671 | -2.45% | Seq Scan on menu_items | Seq Scan on menu_items |
| W04 | WRITE | 9.796 | 15.880 | -62.11% | Seq Scan on restaurants; Seq Scan on reviews | Seq Scan on restaurants; Seq Scan on reviews |
| W05 | WRITE | 7.622 | 21.271 | -179.07% | Seq Scan on customers | Seq Scan on customers |
## What the results show

- **R19 dominates the read improvement.** Its average moved from 4,285.167 ms to 6.713 ms (99.84% lower). The baseline plan scanned orders and reviews while processing restaurant aggregates; the optimized plan includes index-only lookups by restaurant. The rewrite and plan both changed, so this large gain should be attributed to the combined query rewrite and access path rather than an index alone.
- **Several selective lookups improved substantially.** For example, R05 fell from 6.409 ms to 0.163 ms and R12 from 7.253 ms to 0.183 ms. Their optimized plans use partial indexes that contain only preparing orders or eligible unassigned orders, avoiding a scan of the full orders table.
- **Date filtering improved some workloads.** R06 fell from 4.821 ms to 0.206 ms with the date-range rewrite and an orders index; R10 fell from 7.135 ms to 1.130 ms with an indexed time-range plan. R09 improved only 4.59% (22.551 to 21.516 ms), so its large aggregation work remains a bottleneck.
- **Some reads remain costly.** R17 (11.775 ms) and R20 (18.061 ms) still scan orders; R09 (21.516 ms) still processes many qualifying rows. Indexes help when they avoid substantial work, but they cannot remove the cost of aggregating a large result set.
- **Writes are mixed.** W02 improved from 8.789 ms to 0.629 ms, consistent with using the partial ordered index to locate a qualifying order. W01, W03, W04, and W05 were slower in the optimized run; together the five write averages rose from 28.512 ms to 40.446 ms. That is an increase of 11.934 ms (41.85%) across the five separate statement averages. Indexes speed some lookups but require maintenance on inserts and updates. Small timings are sensitive to system activity and cache state.

## Correctness checks

On the seed data, bidirectional `EXCEPT ALL` checks compared complete rows (including duplicate counts) for the rewritten queries listed below. They found no row differences. Ordering among tied rows may vary when the query does not define a unique tie-breaker.

| Query | Original rows | Optimized rows | Differences |
|---|---:|---:|---:|
| R06 | 1 | 1 | 0 |
| R09 | 60 | 60 | 0 |
| R19 | 400 | 400 | 0 |
| R25 | 62 | 62 | 0 |

**R13 is an intentional correctness fix.** The original `NOT IN` returned zero rows because the comparison set included NULL partner IDs (214 recent orders had a NULL partner). The optimized `NOT EXISTS` returned 129 idle partners, matching the NULL-safe reference; the check found zero differences against that reference. This changes the original result and should be explained as a bug fix, not presented as identical-query equivalence.

## Index storage and trade-offs

The catalog check on the indexed seed database found all **17 tuning indexes present and valid**. Their total reported size is **45,056,000 bytes (about 42.97 MiB)**. The index total can be larger than a table’s heap: for example, the restaurant locality/rating index is about 3.02 times the restaurants heap size because it stores key columns, included columns, and index structure. These are seed-dataset sizes, not projected production sizes.

Indexes consume disk space and add work to writes that insert or change indexed values. Partial indexes reduce that cost by storing only qualifying rows; covering indexes can avoid table visits but take more space. The benchmark shows this trade-off: large read savings overall, with slower results on four of the five writes in this particular run.

## Environment and evidence

- PostgreSQL: 18.7 (Postgres.app); session timezone: `Asia/Kolkata`.
- Seed counts checked: 150,000 orders; 375,000 order items; 39,186 reviews.
- Index validation and query-equivalence checks: `CP3_report_evidence(1).txt`.
- Three-run timing summaries: [`baseline summary`](../benchmarks/results/baseline/summary.csv) and [`optimized summary`](../benchmarks/results/optimized/summary.csv).
- Full execution plans: [`baseline plans`](../benchmarks/results/baseline/) and [`optimized plans`](../benchmarks/results/optimized/).
- Index definitions and rewritten workload: [`05_indexes.sql`](../sql/05_indexes.sql) and [`06_optimized_queries.sql`](../sql/06_optimized_queries.sql).

Benchmark results depend on dataset, hardware, database version, cache state, and concurrent activity. The reported checks establish results for this seed dataset and this laptop; they do not establish performance on the faculty’s larger dataset.
