-- ================================
-- CASE STUDY #4: DATA BANK
-- ================================

-- ================================
-- A. CUSTOMER NODES EXPLORATION
-- ================================

-- A1: How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id) AS unique_nodes
FROM data_bank.customer_nodes;

-- A2: What is the number of nodes per region?
SELECT 
    r.region_name,
    COUNT(DISTINCT cn.node_id) AS node_count
FROM data_bank.customer_nodes cn
JOIN data_bank.regions r ON cn.region_id = r.region_id
GROUP BY r.region_name;

-- A3: How many customers are allocated to each region?
SELECT 
    r.region_name,
    COUNT(DISTINCT cn.customer_id) AS customer_count
FROM data_bank.customer_nodes cn
JOIN data_bank.regions r ON cn.region_id = r.region_id
GROUP BY r.region_name;

-- A4: How many days on average are customers reallocated to a different node?
SELECT 
    ROUND(AVG(end_date - start_date), 2) AS avg_reallocation_days
FROM data_bank.customer_nodes
WHERE end_date != '9999-12-31';

-- A5: Median, 80th and 95th percentile for reallocation days per region?
SELECT 
    r.region_name,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY end_date - start_date) AS median_days,
    PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY end_date - start_date) AS p80_days,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY end_date - start_date) AS p95_days
FROM data_bank.customer_nodes cn
JOIN data_bank.regions r ON cn.region_id = r.region_id
WHERE end_date != '9999-12-31'
GROUP BY r.region_name;

-- ================================
-- B. CUSTOMER TRANSACTIONS
-- ================================

-- B1: What is the unique count and total amount for each transaction type?
SELECT 
    txn_type,
    COUNT(*) AS transaction_count,
    SUM(txn_amount) AS total_amount
FROM data_bank.customer_transactions
GROUP BY txn_type;

-- B2: What is the average total historical deposit counts and amounts for all customers?
WITH customer_deposits AS (
    SELECT 
        customer_id,
        COUNT(*) AS deposit_count,
        SUM(txn_amount) AS deposit_amount
    FROM data_bank.customer_transactions
    WHERE txn_type = 'deposit'
    GROUP BY customer_id
)
SELECT 
    ROUND(AVG(deposit_count), 2) AS avg_deposit_count,
    ROUND(AVG(deposit_amount), 2) AS avg_deposit_amount
FROM customer_deposits;

-- B3: For each month - how many customers make more than 1 deposit AND either 1 purchase OR 1 withdrawal?
WITH monthly_activity AS (
    SELECT 
        customer_id,
        DATE_PART('month', txn_date) AS month,
        SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
        SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count,
        SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
    FROM data_bank.customer_transactions
    GROUP BY customer_id, DATE_PART('month', txn_date)
)
SELECT 
    month,
    COUNT(DISTINCT customer_id) AS qualifying_customers
FROM monthly_activity
WHERE deposit_count > 1 
AND (purchase_count >= 1 OR withdrawal_count >= 1)
GROUP BY month
ORDER BY month;

-- B4: What is the closing balance for each customer at the end of each month?
WITH monthly_net AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', txn_date) AS month,
        SUM(CASE 
            WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE -txn_amount 
        END) AS net_amount
    FROM data_bank.customer_transactions
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
)
SELECT 
    customer_id,
    month,
    SUM(net_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS closing_balance
FROM monthly_net
ORDER BY customer_id, month;

-- B5: What is the percentage of customers who increase their closing balance by more than 5%?
WITH signed_txns AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', txn_date) AS txn_month,
        SUM(
            CASE
                WHEN txn_type = 'deposit' THEN txn_amount
                ELSE -txn_amount
            END
        ) AS monthly_net
    FROM data_bank.customer_transactions
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
),
balances AS (
    SELECT
        customer_id,
        txn_month,
        SUM(monthly_net) OVER (
            PARTITION BY customer_id
            ORDER BY txn_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS closing_balance
    FROM signed_txns
),
customer_range AS (
    SELECT
        customer_id,
        FIRST_VALUE(closing_balance) OVER (
            PARTITION BY customer_id
            ORDER BY txn_month
        ) AS first_balance,
        LAST_VALUE(closing_balance) OVER (
            PARTITION BY customer_id
            ORDER BY txn_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_balance
    FROM balances
)
SELECT
    ROUND(
        100.0 * COUNT(DISTINCT customer_id) FILTER (
            WHERE first_balance > 0 
            AND (last_balance - first_balance) / first_balance > 0.05
        ) / COUNT(DISTINCT customer_id), 2
    ) AS pct_customers_increased
FROM customer_range;

-- ================================
-- C. DATA ALLOCATION CHALLENGE
-- ================================

-- C Part 1: Running customer balance per transaction
WITH running_balances AS (
    SELECT 
        customer_id,
        txn_date,
        SUM(
            CASE 
                WHEN txn_type = 'deposit' THEN txn_amount
                ELSE -txn_amount
            END
        ) OVER (
            PARTITION BY customer_id 
            ORDER BY txn_date
        ) AS running_balance
    FROM data_bank.customer_transactions
)
SELECT * FROM running_balances
ORDER BY customer_id, txn_date;

-- C Part 2: Closing balance at end of each month
WITH monthly_net AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', txn_date) AS month,
        SUM(CASE 
            WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE -txn_amount 
        END) AS net_amount
    FROM data_bank.customer_transactions
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
)
SELECT 
    customer_id,
    month,
    SUM(net_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS closing_balance
FROM monthly_net
ORDER BY customer_id, month;

-- C Part 3: Min, avg, max running balance per customer
WITH running_balances AS (
    SELECT 
        customer_id,
        txn_date,
        SUM(
            CASE 
                WHEN txn_type = 'deposit' THEN txn_amount
                ELSE -txn_amount
            END
        ) OVER (
            PARTITION BY customer_id 
            ORDER BY txn_date
        ) AS running_balance
    FROM data_bank.customer_transactions
)
SELECT 
    customer_id,
    MIN(running_balance) AS min_balance,
    AVG(running_balance) AS avg_balance,
    MAX(running_balance) AS max_balance
FROM running_balances
GROUP BY customer_id
ORDER BY customer_id;

-- C Option 1: Data allocated based on previous month closing balance
WITH monthly_net AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', txn_date) AS month,
        SUM(CASE 
            WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE -txn_amount 
        END) AS net_amount
    FROM data_bank.customer_transactions
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
),
closing_balances AS (
    SELECT 
        customer_id,
        month,
        SUM(net_amount) OVER (
            PARTITION BY customer_id 
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS closing_balance
    FROM monthly_net
),
previous_month_balances AS (
    SELECT 
        customer_id,
        month,
        GREATEST(
            LAG(closing_balance) OVER (
                PARTITION BY customer_id 
                ORDER BY month
            ), 0
        ) AS data_allocated
    FROM closing_balances
)
SELECT 
    month,
    SUM(data_allocated) AS total_data_allocated
FROM previous_month_balances
GROUP BY month
ORDER BY month;

-- C Option 2: Data allocated based on average balance in previous 30 days
WITH running_balances AS (
    SELECT 
        customer_id,
        txn_date,
        SUM(
            CASE 
                WHEN txn_type = 'deposit' THEN txn_amount
                ELSE -txn_amount
            END
        ) OVER (
            PARTITION BY customer_id 
            ORDER BY txn_date
        ) AS running_balance
    FROM data_bank.customer_transactions
),
option2_allocation AS (
    SELECT 
        customer_id,
        txn_date,
        GREATEST(
            AVG(running_balance) OVER (
                PARTITION BY customer_id
                ORDER BY txn_date
                RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW
            ), 0
        ) AS data_allocated
    FROM running_balances
)
SELECT 
    DATE_TRUNC('month', txn_date) AS month,
    SUM(data_allocated) AS total_data_allocated
FROM option2_allocation
GROUP BY DATE_TRUNC('month', txn_date)
ORDER BY month;

-- C Option 3: Real-time data allocation
WITH running_balances AS (
    SELECT 
        customer_id,
        txn_date,
        SUM(
            CASE 
                WHEN txn_type = 'deposit' THEN txn_amount
                ELSE -txn_amount
            END
        ) OVER (
            PARTITION BY customer_id 
            ORDER BY txn_date
        ) AS running_balance
    FROM data_bank.customer_transactions
)
SELECT 
    DATE_TRUNC('month', txn_date) AS month,
    SUM(GREATEST(running_balance, 0)) AS total_data_allocated
FROM running_balances
GROUP BY DATE_TRUNC('month', txn_date)
ORDER BY month;

-- ================================
-- D. EXTRA CHALLENGE
-- ================================

-- D1: Simple daily interest (no compounding) at 6% annual rate
WITH customer_dates AS (
    SELECT 
        customer_id,
        MIN(txn_date) AS first_date,
        MAX(txn_date) AS last_date
    FROM data_bank.customer_transactions
    GROUP BY customer_id
),
customer_series AS (
    SELECT 
        cd.customer_id,
        GENERATE_SERIES(cd.first_date, cd.last_date, INTERVAL '1 day')::DATE AS day
    FROM customer_dates cd
),
daily_balances AS (
    SELECT 
        cs.customer_id,
        cs.day,
        COALESCE(
            CASE 
                WHEN ct.txn_type = 'deposit' THEN ct.txn_amount
                ELSE -ct.txn_amount
            END, 0
        ) AS signed_amount
    FROM customer_series cs
    LEFT JOIN data_bank.customer_transactions ct 
        ON cs.customer_id = ct.customer_id 
        AND cs.day = ct.txn_date
),
running_daily_balance AS (
    SELECT 
        customer_id,
        day,
        SUM(signed_amount) OVER (
            PARTITION BY customer_id 
            ORDER BY day
        ) AS running_balance
    FROM daily_balances
),
daily_interest AS (
    SELECT
        customer_id,
        day,
        running_balance,
        GREATEST(running_balance, 0) * (0.06 / 365.0) AS daily_interest_earned
    FROM running_daily_balance
)
SELECT
    DATE_TRUNC('month', day) AS month,
    ROUND(SUM(daily_interest_earned), 2) AS total_simple_interest,
    ROUND(SUM(GREATEST(running_balance, 0) + daily_interest_earned), 2) AS total_data_required
FROM daily_interest
GROUP BY DATE_TRUNC('month', day)
ORDER BY month;

-- D2: Daily compounding interest at 6% annual rate
WITH customer_dates AS (
    SELECT 
        customer_id,
        MIN(txn_date) AS first_date,
        MAX(txn_date) AS last_date
    FROM data_bank.customer_transactions
    GROUP BY customer_id
),
customer_series AS (
    SELECT 
        cd.customer_id,
        GENERATE_SERIES(cd.first_date, cd.last_date, INTERVAL '1 day')::DATE AS day
    FROM customer_dates cd
),
daily_balances AS (
    SELECT 
        cs.customer_id,
        cs.day,
        COALESCE(
            CASE 
                WHEN ct.txn_type = 'deposit' THEN ct.txn_amount
                ELSE -ct.txn_amount
            END, 0
        ) AS signed_amount
    FROM customer_series cs
    LEFT JOIN data_bank.customer_transactions ct 
        ON cs.customer_id = ct.customer_id 
        AND cs.day = ct.txn_date
),
running_daily_balance AS (
    SELECT 
        customer_id,
        day,
        SUM(signed_amount) OVER (
            PARTITION BY customer_id 
            ORDER BY day
        ) AS running_balance
    FROM daily_balances
),
compounded_interest AS (
    SELECT
        customer_id,
        day,
        running_balance,
        GREATEST(running_balance, 0) * 
            POWER(1 + 0.06 / 365.0, 
                ROW_NUMBER() OVER (
                    PARTITION BY customer_id 
                    ORDER BY day
                )
            ) - GREATEST(running_balance, 0) AS compound_interest_earned
    FROM running_daily_balance
)
SELECT
    DATE_TRUNC('month', day) AS month,
    ROUND(SUM(compound_interest_earned), 2) AS total_compound_interest,
    ROUND(SUM(GREATEST(running_balance, 0) + compound_interest_earned), 2) AS total_data_required
FROM compounded_interest
GROUP BY DATE_TRUNC('month', day)
ORDER BY month;
