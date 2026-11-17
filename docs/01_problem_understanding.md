# Phase 1: Problem Understanding & Business Requirements

**Course:** Database Management Systems (DBMS)  
**Project:** Zomato Food Delivery Database  
**Team:** T0002 (Piyush Tharwani, Anubhav Jaiswal, Aadarsh, Prince Goswami)  
**Deliverable:** `docs/01_problem_understanding.md`

---

## 1. Executive Summary & Architecture Context

Zomato's hyper-local food delivery platform connects four core pillars: **hungry customers**, **restaurant partners**, **delivery fleet (riders)**, and **operations/platform management across 10 major Indian metropolitan cities** (each partitioned into 10 distinct localities). 

The legacy database engine currently suffers from a lack of formal relational constraints, missing operational indexes, and suboptimal query patterns that cause severe friction during peak lunch (12:00–15:00) and dinner (19:30–23:00) traffic spikes. The objective of this project is to reverse-engineer a strictly constrained PostgreSQL relational schema from production data exports, establish empirical baseline benchmarks across the 30 critical workload queries, diagnose execution plan bottlenecks, and engineer indexing and structural optimizations capable of sustaining an anticipated 20× operational growth.

---

## 2. Business Problem Analysis (P1 – P10)

The operational bottlenecks reported by stakeholders are categorized below by business need, impacted stakeholder, workload classification, and SLA targets:

| Problem ID | Business Need & Operational Friction | Primary Stakeholder | Workload Classification | Related Queries | SLA Target (Large Dataset) |
|---|---|---|---|---|---|
| **P1** | **Sub-second Home Feed & Restaurant Browsing:** Customers browsing in their locality need instant restaurant listings filtered by operational status (`OPEN`) and ordered by descending rating without database table scans stalling the mobile app during peak meal hours. | Customer | Customer-Facing / Real-Time | R01, R03, R25 | < 5 ms |
| **P2** | **Low-Latency Dish Type-Ahead Search:** Customers searching for popular keywords (e.g., "paneer", "biryani") require interactive type-ahead search across city menus with immediate response times before user keystroke debouncing expires. | Customer & Search Team | Interactive Search | R02 | < 250 ms |
| **P3** | **Instant Order History & Invoice Fetching:** Customers inspecting past orders and viewing digital tax invoices/receipts experience multi-second latency due to unindexed scans over the historical 150k+ order table. | Customer & Billing Team | Customer-Facing / Real-Time | R04, R24 | < 5 ms |
| **P4** | **Real-Time Partner Order Management & Inventory Control:** Restaurant managers need immediate visibility into incoming daily orders, live item-level sales volume, and instant menu item toggling (`is_available = FALSE`) when items sell out. | Restaurant Partners | Customer-Facing & Reporting | R06, R07, R08, W03 | < 5 ms (OLTP) / < 5s (Analytics) |
| **P5** | **Live Dispatch Monitoring & Kitchen Delays:** Fleet coordinators need automated dispatch dashboards refreshing every 5 seconds to highlight unassigned orders and flag kitchen prep delays exceeding 40 minutes. | Dispatch & Operations | Customer-Facing / Real-Time | R05, R12, W01, W02 | < 5 ms |
| **P6** | **Rider Allocation & Idle Fleet Visibility:** Fleet managers require accurate detection of active delivery partners who have not received orders. *(Root Cause: Query R13 returned zero rows because `partner_id NOT IN (SELECT partner_id FROM orders ...)` evaluated to `UNKNOWN` due to unassigned orders with `NULL` partner IDs).* | Delivery Fleet & Operations | Interactive Ops | R11, R13 | < 250 ms |
| **P7** | **Fraud Detection & Real-Time Payment Failure Audits:** Risk and finance teams need fast identification of payment failure spikes across gateways (UPI, CARD, COD, WALLET) and customers exhibiting repeated checkout failures to prevent fraud. | Payments & Risk Team | Interactive Ops & Reporting | R16, R17 | < 250 ms / < 5s |
| **P8** | **Customer Retention & Campaign ROI Analysis:** Marketing and Zomato Gold teams analyze coupon redemption rates, total discounts, average order values, and churn risks for expiring Gold memberships without timing out analytical jobs. | Marketing & Gold Team | Reporting & Analytics | R14, R15, R20, R21, W05 | < 250 ms / < 5s |
| **P9** | **Rapid Escalation of Delivery Delays & Cold Food Complaints:** Customer support agents handling escalations need near-instant filtering for delivery durations exceeding 60 minutes and sentiment filters on negative reviews ("cold food", "stale"). | Customer Support | Interactive Search & Ops | R10, R18 | < 250 ms |
| **P10** | **Executive Macro Dashboards & Heatmaps:** Leadership requires periodic aggregated visibility into city-level delivery durations, order time heatmaps, and restaurant health metrics under heavy data scale. | Executive Leadership & Ops | Analytical & Batch Reporting | R09, R19, R22, R23, W04 | < 5,000 ms (Batch < 2s) |

---

## 3. Workload Classification & Latency Boundaries

To structure benchmarking and optimization targets, the database workload is bifurcated into two foundational regimes:

1. **OLTP / Customer-Facing / Real-Time Workloads (P1, P3, P4-live, P5):**
   - **Characteristics:** High-frequency, concurrent point lookups and small range scans filtered by indexed keys (e.g., `locality_id`, `customer_id`, `order_id`, `restaurant_id`).
   - **Strict Target:** Execution time $\le 5\text{ ms}$ on baseline and $\le 5\text{ ms}$ on the 20× large scale dataset. Must avoid Sequential Scans (`Seq Scan`).

2. **Interactive Search & Operational Cockpits (P2, P6, P7, P9):**
   - **Characteristics:** Moderate-complexity filters involving pattern matching (`ILIKE '%paneer%'`), date range boundaries, status subqueries, and multi-table joins.
   - **Target:** Execution time $\le 250\text{ ms}$.

3. **OLAP / Reporting & Analytical Dashboards (P4-summary, P8, P10):**
   - **Characteristics:** Aggregations (`AVG`, `SUM`, `COUNT`), window functions (`DENSE_RANK`), multi-way joins, and historical grouping over large date ranges.
   - **Target:** Execution time $\le 5,000\text{ ms}$ (Batch nightly jobs $\le 2,000\text{ ms}$).

---

## 4. Key Assumptions

1. **Temporal & Geographic Bounds:** Operational data spans 10 Tier-1 and Tier-2 Indian cities across 100 localities. All timestamps are standardized to Indian Standard Time (`UTC+05:30` / `TIMESTAMPTZ`).
2. **Order Lifecycle Pipeline:** Every order strictly follows the forward state progression:
   $$\text{PLACED} \longrightarrow \text{ACCEPTED} \longrightarrow \text{PREPARING} \longrightarrow \text{OUT\_FOR\_DELIVERY} \longrightarrow \text{DELIVERED}$$
   (or terminating at $\text{CANCELLED\_BY\_CUSTOMER} \text{ / } \text{CANCELLED\_BY\_RESTAURANT}$).
3. **Monetary Integrity:** All prices, discounts, and totals are denominated in INR (₹) using exact fixed-point `NUMERIC(10,2)` representation to eliminate IEEE 754 floating-point inaccuracies. Total calculation strictly obeys:
   $$\text{total\_amount} = \text{item\_total} + \text{delivery\_fee} - \text{discount}$$
4. **Dispatch Mechanics:** Orders in `PLACED` or `ACCEPTED` states may have `partner_id IS NULL`. Rider assignment occurs dynamically during the dispatch lifecycle.
5. **Data Immutability & Soft Deletions:** Critical business entities (customers, restaurants, delivery partners) employ soft lifecycle statuses (`is_active = FALSE`, `TEMPORARILY_CLOSED`, `BLOCKED`) rather than physical deletion to preserve auditability and referential integrity.
