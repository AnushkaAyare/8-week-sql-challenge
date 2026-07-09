---------------------------------
-- CASE STUDY #7: BALANCED TREE
---------------------------------

---------------------------------
-- A: HIGH LEVEL SALES ANALYSIS
---------------------------------

-- A1: Total quantity sold
SELECT SUM(qty) AS total_quantity
FROM balanced_tree.sales;

-- A2: Total revenue before discounts
SELECT SUM(price * qty) AS total_revenue
FROM balanced_tree.sales;

-- A3: Total discount amount
SELECT ROUND(SUM(price * qty * discount / 100.0), 2) AS total_discount
FROM balanced_tree.sales;

---------------------------------
-- B: TRANSACTION ANALYSIS
---------------------------------

-- B1: Unique transactions
SELECT COUNT(DISTINCT txn_id) AS unique_transactions
FROM balanced_tree.sales;

-- B2: Average unique products per transaction
WITH count_products AS (
    SELECT 
        txn_id,
        COUNT(DISTINCT prod_id) AS count_distinct_prod
    FROM balanced_tree.sales
    GROUP BY txn_id
)
SELECT ROUND(AVG(count_distinct_prod), 2) AS avg_unique_products 
FROM count_products;

-- B3: 25th, 50th, 75th percentile of revenue per transaction
WITH revenue AS (
    SELECT 
        txn_id,
        SUM(price * qty * (1 - discount/100.0)) AS revenue
    FROM balanced_tree.sales
    GROUP BY txn_id
)
SELECT 
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY revenue) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue) AS p75
FROM revenue;

-- B4: Average discount value per transaction
WITH discount_per_txn AS (
    SELECT 
        txn_id,
        SUM(price * qty * discount / 100.0) AS discount_value
    FROM balanced_tree.sales
    GROUP BY txn_id
)
SELECT ROUND(AVG(discount_value), 2) AS avg_discount_per_txn
FROM discount_per_txn;

-- B5: Percentage split of transactions — members vs non-members
SELECT 
    member,
    COUNT(DISTINCT txn_id) AS transactions,
    ROUND(100.0 * COUNT(DISTINCT txn_id) / SUM(COUNT(DISTINCT txn_id)) OVER(), 2) AS pct
FROM balanced_tree.sales
GROUP BY member;

-- B6: Average revenue per transaction — members vs non-members
WITH txn_revenue AS (
    SELECT 
        member,
        txn_id,
        SUM(price * qty * (1 - discount/100.0)) AS revenue
    FROM balanced_tree.sales
    GROUP BY member, txn_id
)
SELECT 
    member,
    ROUND(AVG(revenue), 2) AS avg_revenue
FROM txn_revenue
GROUP BY member;

---------------------------------
-- C : Product Analysis
---------------------------------

-- C1: What are the top 3 products by total revenue before discount?
select  s.prod_id,pd.product_name,sum(s.price*s.qty) as revenue 
from balanced_tree.sales s
join balanced_tree.product_details pd 
on s.prod_id=pd.product_id
group by s.prod_id,pd.product_name
order by revenue desc 
limit 3 ;


-- C2: What is the total quantity, revenue and discount for each segment?
SELECT 
    pd.segment_id,
    pd.segment_name,
    SUM(s.qty) AS total_quantity,
    SUM(s.price * s.qty) AS total_revenue,
    ROUND(SUM(s.price * s.qty * s.discount / 100.0), 2) AS total_discount
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.segment_id, pd.segment_name;

-- C3: What is the top selling product for each segment?
WITH ranked AS (
    SELECT 
        pd.segment_name,
        pd.product_name,
        SUM(s.qty) AS total_quantity,
        RANK() OVER (PARTITION BY pd.segment_name ORDER BY SUM(s.qty) DESC) AS rnk
    FROM balanced_tree.sales s
    JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
    GROUP BY pd.segment_name, pd.product_name
)
SELECT segment_name, product_name, total_quantity
FROM ranked
WHERE rnk = 1;


-- C4: What is the total quantity, revenue and discount for each category?
SELECT 
    pd.category_id,
    pd.category_name,
    SUM(s.qty) AS total_quantity,
    SUM(s.price * s.qty) AS total_revenue,
    ROUND(SUM(s.price * s.qty * s.discount / 100.0), 2) AS total_discount
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.category_id, pd.category_name;


-- C5: What is the top selling product for each category?
WITH ranked AS (
    SELECT 
        pd.category_name,
        pd.product_name,
        SUM(s.qty) AS total_quantity,
        RANK() OVER (PARTITION BY pd.category_name ORDER BY SUM(s.qty) DESC) AS rnk
    FROM balanced_tree.sales s
    JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
    GROUP BY pd.category_name, pd.product_name
)
SELECT category_name, product_name, total_quantity
FROM ranked
WHERE rnk = 1;

-- C6: What is the percentage split of revenue by product for each segment?
SELECT 
    pd.segment_name,
    pd.product_name,
    ROUND(100.0 * SUM(s.price * s.qty * (1 - s.discount/100.0)) / 
        SUM(SUM(s.price * s.qty * (1 - s.discount/100.0))) OVER (PARTITION BY pd.segment_name), 2) AS pct_revenue
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.segment_name, pd.product_name
ORDER BY pd.segment_name, pct_revenue DESC;

-- C7: What is the percentage split of revenue by segment for each category?
SELECT 
    pd.segment_name,pd.category_name,
    ROUND(100.0 * SUM(s.price * s.qty * (1 - s.discount/100.0)) / 
        SUM(SUM(s.price * s.qty * (1 - s.discount/100.0))) OVER (PARTITION BY pd.category_name), 2) AS pct_revenue
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.segment_name, pd.category_name
ORDER BY pd.segment_name, pct_revenue DESC;

-- C8: What is the percentage split of total revenue by category?
SELECT 
    pd.category_name,
    ROUND(100.0 * SUM(s.price * s.qty * (1 - s.discount/100.0)) / 
        SUM(SUM(s.price * s.qty * (1 - s.discount/100.0))) OVER (), 2) AS pct_revenue
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.category_name
ORDER BY pct_revenue DESC;


-- C9: What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)

WITH transaction_per_product AS (
    SELECT 
        prod_id,
        COUNT(DISTINCT txn_id) AS total_txn_id
    FROM balanced_tree.sales
    GROUP BY prod_id
),
total_unique_transactions AS (
    SELECT COUNT(DISTINCT txn_id) AS total_unique_txn_id
    FROM balanced_tree.sales
)
SELECT 
    pd.product_name,
    total_txn_id,
    ROUND(100.0 * total_txn_id / total_unique_txn_id, 2) AS penetration_rate
FROM transaction_per_product
CROSS JOIN total_unique_transactions
JOIN balanced_tree.product_details pd ON transaction_per_product.prod_id = pd.product_id
ORDER BY penetration_rate DESC;

-- C10: What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
WITH combinations AS (
    SELECT 
        s1.txn_id,
        s1.prod_id AS product_1,
        s2.prod_id AS product_2,
        s3.prod_id AS product_3
    FROM balanced_tree.sales s1
    JOIN balanced_tree.sales s2 
        ON s1.txn_id = s2.txn_id 
        AND s1.prod_id < s2.prod_id
    JOIN balanced_tree.sales s3 
        ON s1.txn_id = s3.txn_id 
        AND s2.prod_id < s3.prod_id
),
combination_counts AS (
    SELECT 
        product_1,
        product_2,
        product_3,
        COUNT(*) AS combo_count
    FROM combinations
    GROUP BY product_1, product_2, product_3
)
SELECT 
    pd1.product_name AS product_1,
    pd2.product_name AS product_2,
    pd3.product_name AS product_3,
    combo_count
FROM combination_counts
JOIN balanced_tree.product_details pd1 ON product_1 = pd1.product_id
JOIN balanced_tree.product_details pd2 ON product_2 = pd2.product_id
JOIN balanced_tree.product_details pd3 ON product_3 = pd3.product_id
ORDER BY combo_count DESC
LIMIT 1;

---------------------------------
-- Reporting Challenge
---------------------------------
-- Write a single SQL script that combines all of the previous questions into a scheduled report that the Balanced Tree team can run at the beginning of each month to calculate the previous month’s values.

-- Approach: Add WHERE DATE_TRUNC('month', start_date) = '2021-01-01'
-- to each query above for January reporting.
-- Change to '2021-02-01' for February with no other modifications needed.

---------------------------------
-- Bonus Challenge
---------------------------------
-- Use a single SQL query to transform the product_hierarchy and product_prices datasets to the product_details table.
WITH RECURSIVE hierarchy AS (
    -- Anchor: Category level (parent_id IS NULL)
    SELECT 
        id,
        id AS category_id,
        NULL::INTEGER AS segment_id,
        level_text AS category_name,
        NULL::VARCHAR AS segment_name,
        NULL::VARCHAR AS style_name,
        level_name AS level_type
    FROM balanced_tree.product_hierarchy
    WHERE parent_id IS NULL

    UNION ALL

    -- Recursive: children of current level
    SELECT 
        ph.id,
        CASE WHEN ph.level_name = 'Segment' THEN h.category_id ELSE h.category_id END AS category_id,
        CASE WHEN ph.level_name = 'Segment' THEN ph.id ELSE h.segment_id END AS segment_id,
        h.category_name,
        CASE WHEN ph.level_name = 'Segment' THEN ph.level_text ELSE h.segment_name END AS segment_name,
        CASE WHEN ph.level_name = 'Style' THEN ph.level_text ELSE NULL END AS style_name,
        ph.level_name AS level_type
    FROM balanced_tree.product_hierarchy ph
    JOIN hierarchy h ON ph.parent_id = h.id
)
SELECT 
    pp.product_id,
    pp.price,
    h.style_name || ' ' || h.segment_name || ' - ' || h.category_name AS product_name,
    h.category_id,
    h.segment_id,
    h.id AS style_id,
    h.category_name,
    h.segment_name,
    h.style_name
FROM hierarchy h
JOIN balanced_tree.product_prices pp ON h.id = pp.id
WHERE h.level_type = 'Style'
ORDER BY pp.product_id;
