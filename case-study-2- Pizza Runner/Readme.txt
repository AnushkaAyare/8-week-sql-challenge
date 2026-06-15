# Case Study 2: Pizza Runner

**Key Skills:** Data Cleaning, NULL Handling, Aggregations, CTEs, UNNEST, STRING_AGG

## The Business Problem

Pizza Runner delivers pizza "Uber-style." The raw data needed serious cleanup first — inconsistent nulls (`null`, `NaN`, empty strings), mixed units (`"20km"` vs `20`), and wrong data types across the orders and delivery tables.

Once cleaned, the questions covered:

* Pizza Metrics — order volumes, delivery counts, pizza type breakdowns, order timing
* Runner & Customer Experience — pickup times, delivery distances, speed, success rates
* Ingredient Optimisation — standard toppings, common extras/exclusions, ingredient breakdowns per order
* Pricing & Ratings — revenue, a new ratings table, and final profit after runner payouts

## Approach

1. Cleaned `customer_orders`, `runner_orders`, and `pizza_recipes` into temp tables — standardizing nulls, splitting comma-separated values, casting to correct types
2. Used CTEs to separate aggregation from row-level logic, especially for ingredient questions
3. Used UNNEST to break exclusions/extras/toppings strings into individual rows
4. Used STRING_AGG to rebuild ingredient lists (with `2x` prefixes for duplicates)
5. Used EXTRACT(EPOCH FROM ...) for time differences between order and pickup

## Key Takeaway

Aggregated and non-aggregated columns can't live in the same SELECT — aggregation goes in a CTE, the outer query just joins on top. This pattern made the breakdown questions click.

