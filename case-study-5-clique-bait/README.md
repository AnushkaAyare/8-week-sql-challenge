# Case Study #6: Clique Bait

## Business Problem
Clique Bait is an online seafood store founded by Danny, who brings a digital analytics background to the seafood industry. The business runs campaigns and tracks detailed user behaviour across its website. Danny needs to understand funnel fallout rates — where users drop off between viewing a product, adding to cart, and purchasing — and measure the impact of ad campaigns on purchase behaviour.

---

## Dataset

| Table | Description |
|---|---|
| `users` | Website visitors identified by cookie_id |
| `events` | All user interactions — page views, cart adds, purchases, ad impressions and clicks |
| `event_identifier` | Maps event_type integers to event names |
| `page_hierarchy` | All website pages with product category and product_id |
| `campaign_identifier` | Three campaigns run in 2020 with start and end dates |

---

## Key Skills
`Funnel Analysis` `STRING_AGG` `FILTER` `Subqueries` `NOT IN` `Date Range JOIN` `Conditional Aggregation` `Campaign Attribution` `MIN() for session start` `MAX() for binary flags`

---

## What I Solved

### Section 1: ERD
Mapped relationships across all 5 tables:
- `users` → `events` via `cookie_id`
- `events` → `page_hierarchy` via `page_id`
- `events` → `event_identifier` via `event_type`
- `campaign_identifier` connects via date range match on `event_time` — no direct foreign key

### Section 2: Digital Analysis
- Total users and average cookies per user
- Unique visits per month
- Event count by type
- Purchase rate as percentage of all visits
- Checkout abandonment rate — visited checkout but never purchased
- Top 3 pages by views
- Views and cart adds by product category
- Top 3 products by purchases

### Section 3: Product Funnel Analysis
Built two output tables:

**product_funnel** — one row per product with:
- Views, cart adds, abandoned (added to cart but not purchased), purchases

**category_funnel** — same metrics aggregated by product category

From these tables:
- Identified top product by views, cart adds and purchases
- Identified most abandoned product
- Calculated view-to-purchase conversion rate per product
- Calculated average view-to-cart and cart-to-purchase conversion rates

### Section 4: Campaign Analysis
Built a single visit-level summary table with 10 columns per visit including campaign attribution, ad engagement flags, and cart product sequence. Used this to generate 5 business insights:

1. Purchase rate by campaign — which campaign converted best
2. Ad impression impact — whether seeing an ad lifted purchase rate
3. Ad click uplift — quantified difference between clicking vs just seeing an ad
4. Behavioural difference between buyers and non-buyers — page views and cart adds
5. Unique user reach vs conversion rate by campaign period

---

## Approach
Built product and category funnel tables first using conditional aggregation with subqueries — `NOT IN (SELECT visit_id WHERE event_type = 3)` for abandoned, `IN (...)` for purchased. For the campaign table, used a CTE to calculate `visit_start_time` per visit first, then LEFT JOINed `campaign_identifier` on a date range condition — necessary because campaign has no direct foreign key to events. Used `MAX(CASE WHEN event_type = 3 THEN 1 ELSE 0 END)` for the purchase flag rather than SUM to ensure a clean binary output regardless of how many purchase events exist per visit. Used `STRING_AGG FILTER (WHERE event_type = 2) ORDER BY sequence_number` for ordered cart product lists.

---

## Hardest Query
The campaign analysis table — combining 10 different aggregations across 5 event types, a date-range JOIN to campaign_identifier with no foreign key, and STRING_AGG with FILTER and ORDER BY for cart products — all in a single query grouped by visit_id.

---

## Key Takeaway
Funnel analysis is not just counting events — it requires tracking user journeys across multiple rows and sessions. The critical pattern is identifying which visit_ids completed each stage using subqueries, then using conditional aggregation to pivot those conditions into columns. Campaign attribution without a foreign key requires date range JOINs, which must be done after session-level aggregation to avoid joining on raw event rows.

---

## Tools
PostgreSQL 13 · DB Fiddle · GitHub

---

*Part of [Danny Ma's 8 Week SQL Challenge](https://8weeksqlchallenge.com/)*
