# Case Study #5: Data Mart

## Business Problem
Data Mart is Danny's online supermarket specialising in fresh produce with international operations. In June 2020, Data Mart introduced sustainable packaging across its entire supply chain. Danny needs to quantify the sales impact of this change, identify which business areas were most affected, and produce recommendations to minimise disruption from similar changes in future.

---

## Dataset
| Table | Description |
|---|---|
| `weekly_sales` | Single table containing weekly aggregated sales data across regions, platforms, segments and customer types |

---

## Key Skills
`TO_DATE` `EXTRACT` `LEFT` `RIGHT` `CASE WHEN` `Before/After Analysis` `Pivot with conditional aggregation` `GENERATE_SERIES` `Window Functions`

---

## What I Solved

### 1. Data Cleaning
Built a single `clean_weekly_sales` table from raw data including:
- Date format conversion from DD/MM/YY string to DATE type
- Derived columns: week_number, month_number, calendar_year
- Segment decoding into age_band and demographic using LEFT() and RIGHT()
- NULL string handling replaced with 'Unknown'
- avg_transaction calculated as sales divided by transactions

### 2. Data Exploration
- Day of week used for all week_date values
- Missing week numbers identified using GENERATE_SERIES
- Total transactions per year
- Sales by region and month
- Platform transaction breakdown
- Retail vs Shopify percentage of sales per month
- Demographic sales percentage per year
- Top contributing age_band and demographic for Retail
- Correct average transaction size calculation — why AVG(avg_transaction) is wrong

### 3. Before & After Analysis
Measured sales impact of the June 2020 packaging change (baseline: week 25):
- 4-week window: -1.15% decline
- 12-week window: -2.14% decline
- Year-over-year comparison confirmed decline was change-driven, not seasonal

### 4. Bonus — Impact by Business Area
Identified highest negative impact segments across 5 dimensions:

| Dimension | Worst Performer | Change |
|---|---|---|
| Region | Asia | -3.26% |
| Platform | Retail | -2.43% |
| Age Band | Unknown | -3.34% |
| Demographic | Unknown | -3.34% |
| Customer Type | Guest | -3.00% |

Notable: Shopify grew +7.18% and New customers grew +1.01% post-change — sustainability messaging resonated with online and new customer segments.

---

## Approach
Cleaned raw data into a structured table before any analysis. Used CASE WHEN with LEFT() and RIGHT() for segment decoding. Applied the before/after pivot pattern — CASE WHEN inside SUM to convert row-level period labels into comparable columns — across multiple business dimensions. Used GENERATE_SERIES to identify missing week numbers. Validated that AVG(avg_transaction) produces incorrect results compared to SUM(sales)/SUM(transactions).

---

## Hardest Query
The before/after pivot — using conditional aggregation to convert 'Before' and 'After' row values into side-by-side columns for direct comparison, then calculating percentage change in the same query without a subquery.

---

## Key Takeaway
Before/After Analysis is the standard technique for measuring the impact of any business event — product launch, policy change, price update. The correct implementation requires identifying the exact event week, defining symmetric windows, and validating against prior years to rule out seasonal effects.

---

## Business Recommendations
1. Pilot future sustainability changes in Europe and on Shopify first — both showed positive responses
2. Stagger regional rollout — Asia and Oceania need additional preparation and communication
3. Lead sustainability messaging with New customers and Young Adults — most receptive segments
4. Incentivise demographic data collection — Unknown segment is the largest and most negatively impacted
5. Extend measurement window to 6 months — 12 weeks may not capture full customer adjustment period

---

## Tools
PostgreSQL 13 · DB Fiddle · GitHub

---

*Part of [Danny Ma's 8 Week SQL Challenge](https://8weeksqlchallenge.com/)*
