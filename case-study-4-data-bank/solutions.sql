-- ================================
-- CASE STUDY #4: DATA BANK
-- ================================

-- ================================
-- SECTION A: CUSTOMER NODES EXPLORATION
-- ================================

-- A1: How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id) AS unique_nodes
FROM data_bank.customer_nodes;
-- Insight: baseline scale of the network -- more nodes means more
-- distributed storage and higher security.

-- A2: What is the number of nodes per region?
SELECT
    r.region_name,
    COUNT(DISTINCT cn.node_id) AS node_count
FROM data_bank.customer_nodes cn
JOIN data_bank.regions r ON cn.region_id = r.region_id
GROUP BY r.region_name;
-- Insight: uneven node distribution across regions could create
-- security/redundancy gaps -- informs infrastructure investment.

-- A3: How many customers are allocated to each region?
SELECT
    r.region_name,
    COUNT(DISTINCT cn.customer_id) AS customer_count
FROM data_bank.customer_nodes cn
JOIN data_bank.regions r ON cn.region_id = r.region_id
GROUP BY r.region_name;
-- Insight: high customer density in a region with few nodes is an
-- operational risk worth flagging.

-- A4: How many days on average are customers reallocated to a different node?
SELECT
    ROUND(AVG(end_date - start_date), 2) AS avg_reallocation_days
FROM data_bank.customer_nodes
WHERE end_date != '9999-12-31';
-- Insight: 9999-12-31 is a sentinel date marking currently active
-- assignments -- excluding it is necessary or the average is meaningless.

-- A5: What is the median, 80th, and 95th percentile for reallocation days per region?
SELECT
    r.region_name,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY end_date - start_date) AS median_days,
    PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY end_date - start_date) AS p80_days,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY end_date - start_date) AS p95_days
FROM data_bank.customer_nodes cn
JOIN data_bank.regions r ON cn.region_id = r.region_id
WHERE end_date != '9999-12-31'
GROUP BY r.region_name;
-- Insight: percentiles reveal distribution shape averages hide -- a
-- much higher p95 than median means some customers stay far longer
-- than typical, worth investigating given reallocation is a security feature.

-- ================================
-- SECTION B: CUSTOMER TRANSACTIONS
-- ================================

-- B1: What is the unique count and total amount for each transaction type?
SELECT
    txn_type,
    COUNT(*) AS transaction_count,
    SUM(txn_amount) AS total_amount
FROM data_bank.customer_transactions
GROUP BY txn_type;
-- Insight: deposits should dominate in a healthy platform -- if
-- withdrawals/purchases outpace deposits, balances are drawing down.

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
-- Insight: two-step aggregation (per customer, then average across
-- customers) -- doing it in one step gives a different, incorrect number.

-- B3: For each month, how many customers make more than 1 deposit AND either 1 purchase OR 1 withdrawal?
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
-- Insight: conditional aggregation via CASE WHEN inside SUM handles
-- multi-condition filtering in a single pass, cleaner than subqueries.

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
-- Insight: DATE_TRUNC preserves year context -- EXTRACT(MONTH) alone
-- would merge Jan 2020 and Jan 2021 into the same group.

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
-- Insight: the first_balance > 0 guard prevents dividing by a negative
-- or zero balance, which would produce mathematically wrong percentages.

-- ================================
-- SECTION C: DATA ALLOCATION CHALLENGE
-- ================================

-- C1: Running customer balance per transaction.
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
-- Insight: unlike B4's monthly aggregation, this applies the window
-- function to every individual transaction -- a real-time view.

-- C2: Closing balance at the end of each month.
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
-- Insight: same pattern as B4, reused here as the anchor figure the
-- allocation options below build from.

-- C3: Minimum, average, and maximum running balance per customer.
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
-- Insight: high spread between min and max indicates volatile account
-- behaviour -- a provisioning challenge under the real-time model (C6).

-- C4: Allocation Option 1 -- based on previous month's closing balance.
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
-- Insight: LAG() looks one row back per customer, giving last month's
-- balance as this month's allocation. GREATEST(...,0) floors negative
-- balances since negative storage is meaningless. Stable but always one
-- month behind actual balances.

-- C5: Allocation Option 2 -- based on 30-day average balance.
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
-- Insight: RANGE BETWEEN INTERVAL is date-based, not row-based -- looks
-- back 30 calendar days, not 30 rows. Smooths volatility better than
-- Options 1 or 3.

-- C6: Allocation Option 3 -- real-time allocation.
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
-- Insight: reacts instantly to every transaction -- most responsive but
-- also the most volatile, requiring the largest provisioning buffer.

-- ================================
-- SECTION D: INTEREST-BASED ALLOCATION
-- ================================

-- D1: Simple daily interest (no compounding), 6% annual rate.
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
-- Insight: GENERATE_SERIES creates a complete daily date spine per
-- customer; LEFT JOIN brings in transaction amounts where they exist,
-- COALESCE fills gap days with 0. Without this, days with no
-- transactions would be invisible and the running balance would jump
-- incorrectly.

-- D2: Daily compounding interest, 6% annual rate.
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
-- Insight: POWER() applies growth exponentially -- each day's interest
-- builds on all previous days' interest. ROW_NUMBER() provides the
-- exponent (days elapsed). The gap between simple and compound results
-- grows over time -- the figure Data Bank needs before choosing a model.
