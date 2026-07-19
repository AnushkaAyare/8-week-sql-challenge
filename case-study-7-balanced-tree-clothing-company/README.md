# Case Study #7: Balanced Tree Clothing Co.

## Business Problem

Balanced Tree Clothing Company sells an optimised range of clothing and lifestyle wear for the modern adventurer. The CFO needs a monthly financial report covering sales performance, transaction behaviour, and product-level analysis across two categories — Mens and Womens — and twelve individual products organised into segments and styles.

## Dataset

| Table | Description |
|---|---|
| `sales` | Transaction-level sales data with product, quantity, price, discount, member flag, and transaction ID |
| `product_details` | Product metadata — name, category, segment, style, and pricing |
| `product_hierarchy` | Three-level hierarchy: Category → Segment → Style |
| `product_prices` | Product IDs and base prices |

## Key Skills

Self JOIN Recursive CTE PERCENTILE_CONT DENSE_RANK Penetration Rate Revenue After Discount 3-Product Combination Analysis Hierarchical Data Traversal

## What I Solved

**High Level Sales Analysis**
- Total quantity sold across all products
- Total revenue before discounts
- Total discount amount across all products

**Transaction Analysis**
- Unique transaction count
- Average unique products per transaction
- 25th, 50th, 75th percentile of revenue per transaction
- Average discount value per transaction
- Percentage split of transactions — members vs non-members
- Average revenue per transaction — members vs non-members

**Product Analysis**
- Top 3 products by total revenue before discount
- Total quantity, revenue, and discount per segment and per category
- Top selling product per segment and per category using `RANK()`
- Percentage split of revenue by product within segment
- Percentage split of revenue by segment within category
- Percentage split of total revenue by category
- Transaction penetration rate per product
- Most common 3-product combination across all transactions

**Bonus Challenge**

Reconstructed the `product_details` table from scratch using a recursive CTE traversing the 3-level `product_hierarchy` — Category → Segment → Style — carrying parent identifiers forward at each level, then joining to `product_prices` for final output.

## Approach

Used after-discount revenue formula `price * qty * (1 - discount/100.0)` consistently across all revenue calculations. Applied `RANK()` with `PARTITION BY` for top-product-per-segment and top-product-per-category queries. Used the double `SUM` window function pattern for percentage splits — `SUM(revenue) / SUM(SUM(revenue)) OVER (PARTITION BY ...)`. For the 3-product combination query, used a triple self-join on the `sales` table with ascending `prod_id` constraints (`s1.prod_id < s2.prod_id < s3.prod_id`) to generate all unique 3-product combinations per transaction without duplicates, then counted frequency across all transactions. For the bonus recursive CTE, traversed the hierarchy anchor-to-children using `UNION ALL`, carrying `category_id`, `segment_id`, `category_name`, and `segment_name` forward at each level using `CASE WHEN` on `level_name`.

## Hardest Query

Most common 3-product combination — required a triple self-join on the same table within each transaction, with strict ascending product ID ordering to eliminate duplicate combinations, then grouping and counting across all 2,500 transactions. Result: White Tee Shirt - Mens, Grey Fashion Jacket - Womens, Teal Button Up Shirt - Mens appeared together 352 times.

## Key Takeaway

Self-joins are the correct tool when you need to compare multiple rows from the same table within a group — combination analysis, sequential event detection, and ranking problems all follow this pattern. The `<` constraint between joined aliases is what prevents duplicate combinations from inflating counts.

## Tools

PostgreSQL 13 · DB Fiddle · GitHub

*Part of Danny Ma's 8 Week SQL Challenge*
