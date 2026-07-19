-- ================================
-- CASE STUDY #1: DANNY'S DINER
-- ================================

-- ================================
-- SECTION A: CUSTOMER BEHAVIOUR & LOYALTY
-- ================================

-- A1: What is the total amount each customer spent at the restaurant?
SELECT
    s.customer_id,
    SUM(m.price) AS total_spent
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;
-- Insight: Customer A spent the most ($76) -- strongest candidate for a
-- targeted loyalty reward. Customer C spent the least ($36).

-- A2: How many days has each customer visited the restaurant?
SELECT
    customer_id,
    COUNT(DISTINCT order_date) AS days_visited
FROM sales
GROUP BY customer_id;
-- Insight: Customer B visited most (6 days) but spent less than A --
-- high frequency + lower spend signals a price-sensitive customer.

-- A3: What was the first item from the menu purchased by each customer?
WITH ranked AS (
    SELECT
        s.customer_id,
        m.product_name,
        s.order_date,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date ASC) AS rnk
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
)
SELECT customer_id, product_name
FROM ranked
WHERE rnk = 1;
-- Insight: A and C both started with curry; B started with sushi. Curry
-- may be worth featuring for new-customer onboarding.

-- A4: What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
    m.product_name,
    COUNT(s.customer_id) AS total_purchased
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY total_purchased DESC
LIMIT 1;
-- Insight: Ramen ordered 8 times -- clear bestseller, natural anchor
-- product for any loyalty points multiplier.

-- A5: Which item was the most popular for each customer?
WITH ranked AS (
    SELECT
        s.customer_id,
        m.product_name,
        COUNT(s.customer_id) AS purchase_count,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.customer_id) DESC) AS rnk
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, product_name
FROM ranked
WHERE rnk = 1;
-- Insight: A and C both prefer ramen; B orders all items equally.
-- Personalised recommendations are feasible for A and C.

-- A6: Which item was purchased first by the customer after they became a member?
WITH ranked AS (
    SELECT
        s.customer_id,
        m.product_name,
        s.order_date,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date ASC) AS rnk
    FROM sales s
    JOIN members mm ON s.customer_id = mm.customer_id
    JOIN menu m ON s.product_id = m.product_id
    WHERE s.order_date > mm.join_date
)
SELECT customer_id, product_name
FROM ranked
WHERE rnk = 1;
-- Insight: A ordered ramen post-membership, B ordered sushi -- worth
-- tracking whether membership shifts ordering behaviour longer term.

-- A7: Which item was purchased just before the customer became a member?
WITH ranked AS (
    SELECT
        s.customer_id,
        m.product_name,
        s.order_date,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date DESC) AS rnk
    FROM sales s
    JOIN members mm ON s.customer_id = mm.customer_id
    JOIN menu m ON s.product_id = m.product_id
    WHERE s.order_date < mm.join_date
)
SELECT customer_id, product_name
FROM ranked
WHERE rnk = 1;
-- Insight: Both A and B ordered just before joining -- suggests menu
-- quality itself drove membership conversion, not external promotions.

-- A8: What is the total items and amount spent for each member before they became a member?
SELECT
    s.customer_id,
    COUNT(m.product_name) AS total_items,
    SUM(m.price) AS total_spent
FROM sales s
JOIN menu m ON s.product_id = m.product_id
JOIN members mm ON s.customer_id = mm.customer_id
WHERE s.order_date < mm.join_date
GROUP BY s.customer_id;
-- Insight: B spent $40 across 3 items pre-membership vs A's $25 across 2
-- -- B was already a higher-value customer before joining.

-- A9: If each $1 spent equates to 10 points and sushi has a 2x points multiplier, how many points would each customer have?
SELECT
    s.customer_id,
    SUM(
        CASE
            WHEN m.product_name = 'sushi' THEN m.price * 20
            ELSE m.price * 10
        END
    ) AS total_points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;
-- Insight: B leads on points despite lower total spend, purely from
-- sushi order frequency -- the multiplier may need recalibrating.

-- A10: In the first week after a customer joins (including join date) they earn 2x points on all items, not just sushi -- how many points do customer A and B have at the end of January?
SELECT
    s.customer_id,
    SUM(
        CASE
            WHEN s.order_date >= mm.join_date AND s.order_date <= mm.join_date + INTERVAL '6 days' THEN m.price * 20
            WHEN m.product_name = 'sushi' THEN m.price * 20
            ELSE m.price * 10
        END
    ) AS total_points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
JOIN members mm ON s.customer_id = mm.customer_id
WHERE s.order_date <= '2021-01-31'
GROUP BY s.customer_id;
-- Insight: A benefits more from the first-week bonus due to order timing
-- -- an effective acquisition incentive that rewards immediate engagement.

-- ================================
-- SECTION B: BONUS QUESTIONS
-- ================================

-- B1: One clean table with all purchases showing whether the customer was a member at the time of that purchase.
SELECT s.customer_id, s.order_date, m.product_name, m.price,
    CASE
        WHEN s.order_date >= mm.join_date THEN 'Y'
        ELSE 'N'
    END AS members
FROM sales s
LEFT JOIN members mm ON s.customer_id = mm.customer_id
JOIN menu m ON s.product_id = m.product_id;
-- Insight: LEFT JOIN used deliberately -- Customer C never joined
-- membership, so INNER JOIN would silently exclude all their records.

-- B2: Rank orders within membership period.
WITH bonus1 AS (
    SELECT s.customer_id, s.order_date, m.product_name, m.price,
        CASE
            WHEN s.order_date >= mm.join_date THEN 'Y'
            ELSE 'N'
        END AS members
    FROM sales s
    LEFT JOIN members mm ON s.customer_id = mm.customer_id
    JOIN menu m ON s.product_id = m.product_id
)
SELECT
    customer_id,
    order_date,
    product_name,
    price,
    members,
    CASE
        WHEN members = 'N' THEN NULL
        ELSE DENSE_RANK() OVER (
            PARTITION BY customer_id, members
            ORDER BY order_date ASC
        )
    END AS ranking
FROM bonus1;
-- Insight: Non-members left unranked (NULL) by design -- ranking only
-- applies within the membership period.
