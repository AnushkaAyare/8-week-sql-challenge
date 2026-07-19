# Case Study #6: Clique Bait

## Business Problem

Clique Bait is Danny's online seafood store. The business wants to understand how customers move through the site — from ad impression to click, to page views, to cart adds, to purchase — in order to identify where the funnel leaks and which marketing campaigns actually drive revenue.

## Dataset

| Table | Description |
|---|---|
| `users` | Maps user_id to cookie_id (one user can have multiple cookies) |
| `events` | Every page/product interaction, tagged by event_type and visit_id |
| `event_identifier` | Lookup for event_type → event_name (Page View, Add to Cart, Purchase, Ad Impression, Ad Click) |
| `page_hierarchy` | Page metadata including product_category and product_id |
| `campaign_identifier` | Campaign name and date range |

## Key Skills

JOIN CASE WHEN Conditional Aggregation Funnel Analysis Correlated Subqueries STRING_AGG FILTER Date-Range JOIN CTE Table Construction

## What I Solved

**Digital Analysis**
- Total unique users and average cookies per user
- Unique visits per month
- Event counts by event type
- % of visits with a purchase event
- % of visits that reached checkout but did not purchase
- Top 3 pages by views
- Views and cart adds by product category
- Top 3 products by purchases

**Product Funnel Analysis**

Built two funnel tables (`product_funnel`, `category_funnel`) using conditional aggregation to compute, per product and per category:
- Views, cart adds, abandoned carts, purchases
- Which product had the most views / cart adds / purchases
- Which product had the highest view-to-purchase conversion
- Average view→cart and cart→purchase conversion rates across all products

**Campaign Analysis**

Built a `campaign_analysis` table joining visit-level behavior (page views, cart adds, purchase flag, impressions, clicks, cart product list via `STRING_AGG ... FILTER`) to the campaign a visit fell into, using a date-range join between visit start time and campaign start/end dates.

From this table, derived:
- Purchase rate by campaign
- Purchase rate: saw an ad impression vs. no impression
- Purchase rate: clicked the ad vs. saw it only vs. no ad exposure
- Average page views and cart adds split by purchase outcome
- Most-visited campaign period by unique users, with purchase rate

## Approach

Built the funnel tables as intermediate physical tables rather than repeated subqueries, since the same product/category-level aggregates were needed across multiple questions. The campaign date-range join (`visit_start_time BETWEEN start_date AND end_date`) was the key technique for attributing behavior to a campaign without a foreign key. `STRING_AGG` with `FILTER (WHERE event_type = 2)` and an `ORDER BY sequence_number` inside the aggregate reconstructed the ordered list of products added to cart per visit — without needing a separate query per visit.

## Hardest Query

The `campaign_analysis` table build: combining a visit-level `GROUP BY` (with multiple conditional SUMs for different event types) with a date-range join to a separate campaign table, while also aggregating an ordered, filtered product list in the same pass — all in a single CTE.

## Key Takeaway

Funnel analysis isn't just "count views, count purchases" — the real insight is in the conversion rate between stages, because that's where you find whether the problem is discovery (view→cart) or checkout friction (cart→purchase). Similarly, campaign attribution via date ranges (not foreign keys) is a pattern that shows up constantly in marketing analytics when there's no direct link between a user action and a campaign table.

## Tools

PostgreSQL 13 · DB Fiddle · GitHub

*Part of Danny Ma's 8 Week SQL Challenge*
