-- ================================
-- CASE STUDY #3: FOODIE-FI
-- ================================

-- ================================
-- SECTION A: CUSTOMER JOURNEY
-- ================================

-- A1: What does each customer's subscription journey look like, in order?
SELECT
    s.customer_id,
    p.plan_name,
    s.start_date
FROM subscriptions s
JOIN plans p ON s.plan_id = p.plan_id
ORDER BY s.customer_id, s.start_date;
-- Insight: every customer starts on trial. What happens next is the
-- core business question this case study answers.

-- ================================
-- SECTION B: DATA ANALYSIS
-- ================================

-- B1: How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM subscriptions;
-- Insight: this is the denominator for every percentage calculation below.

-- B2: What is the monthly distribution of trial plan starts?
SELECT
    DATE_TRUNC('month', start_date) AS month,
    COUNT(DISTINCT customer_id) AS count
FROM subscriptions
WHERE plan_id = 0
GROUP BY DATE_TRUNC('month', start_date)
ORDER BY DATE_TRUNC('month', start_date);
-- Insight: a trial spike without a matching conversion spike is an
-- early churn warning signal.

-- B3: What is the breakdown of plan events that occurred after 2020?
SELECT
    p.plan_name,
    COUNT(*) AS events
FROM subscriptions s
JOIN plans p ON s.plan_id = p.plan_id
WHERE start_date >= '2021-01-01'
GROUP BY p.plan_name;
-- Insight: shows whether the 2020 cohort kept engaging or churned once
-- into 2021.

-- B4: What is the customer count and percentage that churned?
SELECT
    COUNT(*) AS churned_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 1) AS churn_percentage
FROM subscriptions
WHERE plan_id = 4;
-- Insight: churn rate is the single most important subscription health
-- metric -- a high rate means acquisition spend is being wasted.

-- B5: How many customers churned straight after their trial?
WITH next_plan AS (
    SELECT
        customer_id,
        plan_id,
        LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date ASC) AS next_plan_id
    FROM subscriptions
)
SELECT
    COUNT(DISTINCT customer_id) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) AS percentage
FROM next_plan
WHERE plan_id = 0 AND next_plan_id = 4;
-- Insight: trial-to-churn customers never found value -- a high rate
-- means the trial experience needs fixing before marketing spend does.

-- B6: What is the post-trial plan distribution?
WITH next_plan AS (
    SELECT
        s.customer_id,
        s.plan_id,
        LEAD(p.plan_name) OVER (PARTITION BY customer_id ORDER BY start_date ASC) AS next_plan_name,
        LEAD(s.plan_id) OVER (PARTITION BY customer_id ORDER BY start_date ASC) AS next_plan_id
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.plan_id
)
SELECT
    COUNT(DISTINCT customer_id) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) AS percentage,
    next_plan_id,
    next_plan_name
FROM next_plan
WHERE plan_id = 0
GROUP BY next_plan_id, next_plan_name;
-- Insight: if most trial customers land on basic rather than pro
-- monthly, it signals price sensitivity in the trial-to-paid gap.

-- B7: What is the customer count and plan distribution at 2020-12-31?
WITH ranked_plans AS (
    SELECT
        customer_id,
        plan_id,
        start_date,
        DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY start_date DESC) AS rn
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
)
SELECT
    p.plan_name,
    COUNT(DISTINCT r.customer_id) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) AS percentage
FROM ranked_plans r
JOIN plans p ON r.plan_id = p.plan_id
WHERE rn = 1
GROUP BY p.plan_name, r.plan_id
ORDER BY r.plan_id;
-- Insight: a point-in-time snapshot -- DENSE_RANK ordered by
-- start_date DESC, rank = 1 gives each customer's current plan.

-- B8: How many customers upgraded to an annual plan in 2020?
SELECT COUNT(DISTINCT customer_id) AS count
FROM subscriptions
WHERE plan_id = 3
AND EXTRACT(YEAR FROM start_date) = 2020;
-- Insight: annual customers are the highest-value segment -- paid
-- upfront, zero monthly churn risk.

-- B9: What is the average number of days from trial to annual upgrade?
WITH trial AS (
    SELECT customer_id, start_date AS trial_date
    FROM subscriptions
    WHERE plan_id = 0
),
annual AS (
    SELECT customer_id, start_date AS annual_date
    FROM subscriptions
    WHERE plan_id = 3
)
SELECT ROUND(AVG(annual_date - trial_date)) AS avg_days_to_annual
FROM trial t
JOIN annual a ON t.customer_id = a.customer_id;
-- Insight: sets the consideration-cycle length -- a discount offer
-- timed just before this average could accelerate conversions.

-- B10: Can this average be broken into 30-day buckets?
WITH trial AS (
    SELECT customer_id, start_date AS trial_date
    FROM subscriptions
    WHERE plan_id = 0
),
annual AS (
    SELECT customer_id, start_date AS annual_date
    FROM subscriptions
    WHERE plan_id = 3
),
days_diff AS (
    SELECT
        t.customer_id,
        (a.annual_date - t.trial_date) AS days
    FROM trial t
    JOIN annual a ON t.customer_id = a.customer_id
)
SELECT
    CASE
        WHEN days <= 30 THEN '0-30 days'
        WHEN days <= 60 THEN '31-60 days'
        WHEN days <= 90 THEN '61-90 days'
        WHEN days <= 120 THEN '91-120 days'
        WHEN days <= 150 THEN '121-150 days'
        WHEN days <= 180 THEN '151-180 days'
        WHEN days <= 210 THEN '181-210 days'
        WHEN days <= 240 THEN '211-240 days'
        WHEN days <= 270 THEN '241-270 days'
        WHEN days <= 300 THEN '271-300 days'
        WHEN days <= 330 THEN '301-330 days'
        WHEN days <= 360 THEN '331-360 days'
        ELSE '360+ days'
    END AS bucket,
    COUNT(customer_id) AS count
FROM days_diff
GROUP BY bucket
ORDER BY MIN(days);
-- Insight: reveals when the annual decision actually happens -- a
-- cluster in the 0-30 bucket means customers decide fast.

-- B11: How many customers downgraded from pro monthly to basic monthly?
WITH next_plan AS (
    SELECT
        customer_id,
        plan_id,
        LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date ASC) AS next_plan_id
    FROM subscriptions
)
SELECT
    COUNT(DISTINCT customer_id) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) AS percentage
FROM next_plan
WHERE plan_id = 2 AND next_plan_id = 1;
-- Insight: downgrades are salvageable dissatisfaction -- worth
-- investigating before it becomes full churn.

-- ================================
-- SECTION C: PAYMENTS TABLE
-- ================================

-- C1: Build a full recursive payments table for 2020.
WITH RECURSIVE base AS (
    SELECT
        s.customer_id,
        s.plan_id,
        p.plan_name,
        s.start_date,
        LEAD(s.start_date) OVER (PARTITION BY s.customer_id ORDER BY s.start_date) AS next_date,
        p.price
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.plan_id
    WHERE p.plan_name != 'trial'
    AND EXTRACT(YEAR FROM s.start_date) <= 2020
),
payments AS (
    SELECT
        customer_id,
        plan_id,
        plan_name,
        start_date AS payment_date,
        price AS amount,
        COALESCE(next_date, '2020-12-31') AS end_date
    FROM base
    WHERE plan_name != 'churn'

    UNION ALL

    SELECT
        customer_id,
        plan_id,
        plan_name,
        (payment_date + INTERVAL '1 month')::date,
        amount,
        end_date
    FROM payments
    WHERE (plan_name = 'basic monthly' OR plan_name = 'pro monthly')
    AND (payment_date + INTERVAL '1 month') <= end_date
    AND (payment_date + INTERVAL '1 month') <= '2020-12-31'
)
SELECT
    customer_id,
    plan_id,
    plan_name,
    payment_date,
    CASE
        WHEN LAG(plan_id) OVER (PARTITION BY customer_id ORDER BY payment_date) != plan_id
        AND LAG(payment_date) OVER (PARTITION BY customer_id ORDER BY payment_date)
            BETWEEN payment_date - INTERVAL '1 month' AND payment_date
        THEN amount - LAG(amount) OVER (PARTITION BY customer_id ORDER BY payment_date)
        ELSE amount
    END AS amount,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY payment_date) AS payment_order
FROM payments
ORDER BY customer_id, payment_date;
-- Insight: the recursive CTE acts as a billing engine -- the anchor sets
-- the first payment, each recursive step adds one month until year end
-- or cancellation. The LAG() in the final SELECT handles proration when
-- a customer upgrades mid-cycle: they pay only the price difference.

-- ================================
-- SECTION D: BUSINESS ANALYSIS
-- ================================

-- D1: Rate of growth.
-- Compare active paying customers month over month:
-- (COUNT this month - COUNT last month) / COUNT last month * 100
-- Same approach works for MRR (Monthly Recurring Revenue) growth.

-- D2: Key metrics to track.
-- Monthly active subscribers per plan
-- Churn rate month over month
-- Trial to paid conversion rate
-- Average revenue per user (ARPU)
-- Time to upgrade from trial

-- D3: Customer journeys to analyse.
-- Customers who churned straight after trial -- why didn't they convert?
-- Customers who downgraded -- what triggered dissatisfaction?
-- Customers who upgraded to annual -- what made them commit long term?

-- D4: Exit survey questions.
-- Why are you cancelling today?
-- What was missing from Foodie-Fi's content?
-- How was your overall streaming experience?
-- Would a lower price point have kept you subscribed?
-- Would you consider returning in the future?

-- D5: Reducing churn.
-- Offer discounted first month to trial users who haven't converted
-- Send personalised content recommendations to increase engagement
-- Offer pause option instead of full cancellation
-- Validate by A/B testing each lever and measuring churn rate before vs after
