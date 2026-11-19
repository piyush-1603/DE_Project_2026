# CP2 Baseline Timings

## Environment and method

- Contributor — Anubhav Jaiswal, Team T0002.
- Machine — Anubhav’s MacBook Pro. CPU, RAM and macOS version were not recorded in the supplied evidence. Use this same laptop for the optimized benchmark.
- Server — PostgreSQL 18.7 from Postgres.app, as reported by the local server. The psql client reports PostgreSQL 16.15 from Homebrew.
- Connection — localhost. Database — `zomato_cp2_baseline`. Schema — `zomato`.
- Dataset — the supplied 11 seed CSVs. The successful load output reported all expected row counts, including 150,000 orders, and completed ANALYZE.
- Schema — team schema loaded before benchmarking. No tuning-index creation was performed in the shown workflow. The supplied plans use primary-key indexes where applicable.
- Workload — unchanged `queries/workload_30.sql`, containing 25 READ queries and 5 WRITE queries.
- Command — `PGHOST=localhost bash benchmarks/run_benchmark.sh zomato_cp2_baseline baseline 3`.
- Measurement — three executions per query using `EXPLAIN (ANALYZE, BUFFERS)`. The reported value is PostgreSQL Execution Time in milliseconds. The arithmetic mean is rounded to three decimal places. Planning Time is excluded.
- Writes — the supplied benchmark script wraps each write execution in BEGIN and ROLLBACK. Rollback and transaction-commit latency are outside the reported query Execution Time.
- Cache — the supplied workflow adds no explicit warm-up or cache-reset step. These measurements reflect the local cache state after loading and ANALYZE.
- Evidence — `benchmarks/results/baseline/summary.csv` and the 30 per-query text files in that folder contain the original benchmark output.

## Seed row counts

| Table | Rows |
| --- | ---: |
| cities | 10 |
| localities | 100 |
| customers | 25,000 |
| delivery_partners | 2,000 |
| coupons | 30 |
| restaurants | 2,500 |
| menu_items | 50,000 |
| orders | 150,000 |
| order_items | 375,000 |
| payments | 137,378 |
| reviews | 39,186 |

## Execution timings

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| R01 — Home feed | READ | 0.280 | 0.276 | 0.280 | 0.279 |
| R02 — Paneer dish search | READ | 21.609 | 19.922 | 16.199 | 19.243 |
| R03 — Restaurant menu | READ | 2.280 | 1.704 | 1.730 | 1.905 |
| R04 — Customer order history | READ | 4.884 | 4.760 | 4.767 | 4.804 |
| R05 — Kitchen-delay alert | READ | 6.568 | 6.303 | 6.355 | 6.409 |
| R06 — Restaurant daily orders | READ | 4.886 | 4.824 | 4.754 | 4.821 |
| R07 — Dish-wise sales | READ | 5.723 | 5.763 | 5.974 | 5.820 |
| R08 — Restaurant bestsellers | READ | 6.546 | 6.391 | 6.154 | 6.364 |
| R09 — Monthly delivery times | READ | 22.541 | 22.682 | 22.430 | 22.551 |
| R10 — Late June deliveries | READ | 8.769 | 7.349 | 5.286 | 7.135 |
| R11 — Partner weekly earnings | READ | 5.968 | 8.403 | 5.553 | 6.641 |
| R12 — Unassigned orders | READ | 7.429 | 7.113 | 7.217 | 7.253 |
| R13 — Idle delivery partners | READ | 6.597 | 5.878 | 5.678 | 6.051 |
| R14 — Expiring Gold members | READ | 6.823 | 6.889 | 6.685 | 6.799 |
| R15 — Coupon effectiveness | READ | 13.761 | 13.876 | 13.648 | 13.762 |
| R16 — Recent failed payments | READ | 3.995 | 4.007 | 3.829 | 3.944 |
| R17 — Customers with repeated failures | READ | 15.473 | 14.660 | 14.832 | 14.988 |
| R18 — Review moderation | READ | 12.069 | 11.748 | 11.747 | 11.855 |
| R19 — Restaurant health | READ | 4364.208 | 4249.779 | 4241.515 | 4285.167 |
| R20 — Top Mumbai customers | READ | 20.942 | 18.958 | 18.725 | 19.542 |
| R21 — Repeat customers by city | READ | 9.875 | 9.769 | 9.487 | 9.710 |
| R22 — Order heatmap | READ | 13.473 | 13.306 | 13.132 | 13.304 |
| R23 — Deep order pagination | READ | 34.267 | 33.500 | 41.712 | 36.493 |
| R24 — Order bill | READ | 5.381 | 5.155 | 4.870 | 5.135 |
| R25 — Cuisine filter | READ | 0.307 | 0.311 | 0.318 | 0.312 |
| W01 — Place an order | WRITE | 0.864 | 0.599 | 0.560 | 0.674 |
| W02 — Assign a delivery partner | WRITE | 9.454 | 8.509 | 8.403 | 8.789 |
| W03 — Hide sold-out desserts | WRITE | 1.681 | 1.616 | 1.595 | 1.631 |
| W04 — Recompute restaurant ratings | WRITE | 10.677 | 9.543 | 9.169 | 9.796 |
| W05 — Expire Gold memberships | WRITE | 7.854 | 7.569 | 7.443 | 7.622 |
| **Total (sum of all 30)** | | 4635.184 | 4511.162 | 4500.047 | 4548.798 |

The total is a sum of query execution times. It excludes connection setup, planning and other benchmark-script overhead.

## Scan types and plan observations

Scan nodes below preserve the Parallel designation found in the raw plans. Observations refer to the supplied execution plans, with row counts and disk usage taken from run 1.

| Query | Scan nodes | Observation |
| --- | --- | --- |
| R01 | Seq Scan on restaurants / Seq Scan on localities | Restaurant and locality tables are scanned and joined, then 34 matching restaurants are sorted. Their small size keeps execution below 1 ms. |
| R02 | Seq Scan on menu_items / Seq Scan on restaurants / Seq Scan on localities | All 50,000 menu items are checked for availability and the paneer substring, followed by joins and a top-N price sort. Text filtering dominates the first run. |
| R03 | Seq Scan on menu_items | All 50,000 menu items are scanned to retrieve 18 available dishes for restaurant 217, followed by a small sort. |
| R04 | Seq Scan on orders / Index Scan using restaurants_pkey on restaurants | Orders are scanned to find nine customer orders, then restaurant primary-key lookups and a small date sort complete the result. |
| R05 | Parallel Seq Scan on orders | A parallel scan filters orders by PREPARING status and acceptance time, then Gather Merge combines the sorted results. |
| R06 | Parallel Seq Scan on orders | A parallel orders scan evaluates the restaurant filter and date conversion to return a single row. |
| R07 | Parallel Seq Scan on orders / Index Scan using order_items_pkey on order_items / Index Scan using menu_items_pkey on menu_items | A parallel orders scan finds the relevant delivered orders, primary-key lookups retrieve items, and aggregation computes dish sales. |
| R08 | Parallel Seq Scan on orders / Seq Scan on restaurants / Seq Scan on localities / Index Scan using order_items_pkey on order_items | A parallel orders scan feeds restaurant and locality joins and indexed order-item lookups, followed by aggregation, ranking and incremental sorts. |
| R09 | Parallel Seq Scan on orders / Seq Scan on restaurants / Seq Scan on localities | A parallel orders scan applies the year expression and delivery status, then joins, sorting and monthly aggregation process 43,141 qualifying orders. |
| R10 | Parallel Seq Scan on orders | A parallel orders scan computes delivery duration and filters June orders, followed by a top-N duration sort. |
| R11 | Parallel Seq Scan on orders | A parallel orders scan searches for partner 150's deliveries in the specified week, returning two rows for aggregation. |
| R12 | Seq Scan on orders | All orders are scanned to find 75 unassigned PLACED or ACCEPTED orders, which are sorted to return the oldest 50. |
| R13 | Seq Scan on delivery_partners / Seq Scan on orders | Orders are scanned for the hashed subplan and all 2,000 partners are filtered. The result contains zero partners. Investigate the supplied NOT IN query's NULL semantics during correctness review. |
| R14 | Seq Scan on orders / Seq Scan on customers | Sequential scans filter June orders and expiring Gold customers, and a hash semi join returns the 379 matching customers. |
| R15 | Seq Scan on orders / Seq Scan on coupons | Delivered orders are scanned and joined to coupons, then aggregated and sorted to produce the coupon report. |
| R16 | Seq Scan on payments | All 137,378 payments are scanned to find 82 recent failures before grouping and sorting by method. |
| R17 | Seq Scan on orders / Seq Scan on payments | Orders and failed payments are scanned and hash-joined, then customer aggregation and sorting produce the risk report. |
| R18 | Seq Scan on reviews | Every review is checked against the cold and late substring filters, followed by a top-N sort on creation time. |
| R19 | Seq Scan on restaurants / Seq Scan on localities / Seq Scan on orders / Seq Scan on reviews | Three correlated subplans each execute 400 times, with two repeated full orders scans and one repeated reviews scan per restaurant. These scans dominate execution. |
| R20 | Seq Scan on orders / Seq Scan on customers | Delivered orders and Mumbai customers are scanned and hash-joined, then spending is aggregated and a top-N sort selects 20 customers. |
| R21 | Seq Scan on customers / Seq Scan on orders | Orders are scanned for May and grouped by customer, then joined to customers and aggregated by city. |
| R22 | Seq Scan on orders / Seq Scan on restaurants / Seq Scan on localities | Orders are scanned for the eight-week range and joined to restaurant/locality data, then weekday/hour expressions are sorted and aggregated. |
| R23 | Seq Scan on orders | All 150,000 orders are scanned and sorted. The external merge sort spills 7,664 kB to disk in run 1, and OFFSET discards 100,000 rows. |
| R24 | Index Scan using orders_pkey on orders / Index Scan using restaurants_pkey on restaurants / Seq Scan on payments / Index Scan using order_items_pkey on order_items / Index Scan using menu_items_pkey on menu_items | Primary-key indexes locate the order, restaurant and dishes, but payments are fully scanned to find the successful payment for that order. |
| R25 | Seq Scan on restaurants / Seq Scan on localities | Small restaurant and locality scans evaluate the cuisine array and open status, followed by a rating sort. |
| W01 | No table scan (Result node) | A single row is inserted through a Result node with no table scan. Foreign-key trigger checks contribute to execution time. |
| W02 | Seq Scan on orders / Index Scan using orders_pkey on orders | A full orders scan and top-N sort locate the oldest eligible order, then a primary-key lookup updates it and a foreign-key trigger checks the partner. |
| W03 | Seq Scan on menu_items | All 50,000 menu items are scanned to find and update two matching dessert rows. |
| W04 | Seq Scan on restaurants / Seq Scan on reviews | All reviews are scanned and aggregated by restaurant, then joined to restaurants to update 2,390 rows. Update work also dirties buffers. |
| W05 | Seq Scan on customers | All 25,000 customers are scanned to find 1,230 expired Gold memberships, and the updates dirty buffers. |

## Baseline findings

R19 is the largest measured bottleneck at 4285.167 ms on average, accounting for approximately 94.2% of the sum of all query averages. Its correlated subplans repeatedly scan orders and reviews for 400 restaurants.

R23 averages 36.493 ms and spills its sort to disk. R02 and R18 perform substring searches through sequential scans. R24 uses primary-key lookups for most joins but scans the entire payments table.

R13 returns zero rows in the baseline. That result alone does not establish that the fleet is fully assigned. The NOT IN subquery and nullable partner_id require a separate correctness investigation. The baseline preserves the supplied query.

These results establish the starting measurements. Optimized measurements and correctness comparisons remain pending.

## Evidence validation

The submitted ZIP contains exactly one summary CSV and 30 query-plan files. Each plan file contains three numbered runs and three Execution Time values, for 90 measured executions in total. Query IDs cover R01–R25 and W01–W05. Recomputed averages, medians, minima and maxima agree with summary.csv to the reported precision.
