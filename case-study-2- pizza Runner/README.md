# Case Study #2: Pizza Runner

## Business Problem

Pizza Runner delivers pizza Uber-style across a network of runners. The raw data arrived with serious quality issues — inconsistent NULLs, mixed units, wrong data types — requiring full cleaning before any analysis. Once cleaned, the questions covered order volumes, runner performance, ingredient optimisation, and pricing.

## Dataset

| Table | Description |
|---|---|
| `customer_orders` | Pizza orders with extras and exclusions |
| `runner_orders` | Delivery assignments with distance, duration, cancellations |
| `pizza_names` | Pizza IDs and names |
| `pizza_recipes` | Standard toppings per pizza |
| `pizza_toppings` | Topping IDs and names |
| `runners` | Runner registration dates |

## Key Skills

Data Cleaning NULL Handling UNNEST STRING_AGG CTE Aggregations EXTRACT(EPOCH)

## What I Solved

**Pizza Metrics**
- Order volumes, delivery counts, pizza type breakdowns, order timing

**Runner & Customer Experience**
- Pickup times, delivery distances, speed, success rates

**Ingredient Optimisation**
- Standard toppings, most common extras and exclusions, full ingredient breakdown per order

**Pricing & Ratings**
- Revenue calculation, ratings table design, final profit after runner payouts

## Approach

Cleaned `customer_orders`, `runner_orders`, and `pizza_recipes` into temp tables first — standardising NULLs, splitting comma-separated values, casting to correct types. Used CTEs to separate aggregation from row-level logic. Used `UNNEST` to break exclusion and extras strings into individual rows. Used `STRING_AGG` to rebuild ingredient lists with 2x prefix for duplicates. Used `EXTRACT(EPOCH FROM ...)` for time difference calculations between order and pickup.

## Hardest Query

The full ingredient breakdown per order — requiring `UNNEST` to explode toppings, exclusions, and extras into rows, then `STRING_AGG` to rebuild the final ingredient string with duplicate handling.

## Key Takeaway

Aggregated and non-aggregated columns cannot live in the same `SELECT` — aggregation goes in a CTE, the outer query joins on top. This pattern is what made the ingredient breakdown questions solvable.

## Tools

PostgreSQL 13 · DB Fiddle · GitHub

*Part of Danny Ma's 8 Week SQL Challenge*
