/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

-- Q1: Total amount each customer spent
SELECT 
    s.customer_id,
    SUM(m.price) AS total_spent
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- Q2: How many days each customer visited
SELECT 
    customer_id,
    COUNT(DISTINCT order_date) AS days_visited
FROM sales
GROUP BY customer_id;

-- Q3: First item purchased by each customer
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

-- Q4: Most purchased item overall
SELECT 
    m.product_name, 
    COUNT(s.customer_id) AS total_purchased
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY total_purchased DESC
LIMIT 1;

-- Q5: Most popular item per customer
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

-- 6. Which item was purchased first by the customer after they became a member?

WITH ranked AS (

    SELECT 
        s.customer_id,
        m.product_name,
        s.order_date,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date asc) AS rnk
    FROM sales s
    JOIN members mm ON s.customer_id = mm.customer_id
    JOIN menu m ON s.product_id = m.product_id
    WHERE s.order_date > mm.join_date
)
SELECT customer_id, product_name
FROM ranked
WHERE rnk = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH ranked AS (

    SELECT 
        s.customer_id,
        m.product_name,
        s.order_date,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date desc) AS rnk
    FROM sales s
    JOIN members mm ON s.customer_id = mm.customer_id
    JOIN menu m ON s.product_id = m.product_id
    WHERE s.order_date < mm.join_date
)
SELECT customer_id, product_name
FROM ranked
WHERE rnk = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT 
    s.customer_id,
    COUNT(m.product_name) AS total_items,
    SUM(m.price) AS total_spent
FROM sales s
JOIN menu m ON s.product_id = m.product_id
JOIN members mm ON s.customer_id = mm.customer_id
WHERE s.order_date < mm.join_date
GROUP BY s.customer_id;
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT 
    s.customer_id,
    SUM(
        CASE 
            WHEN m.product_name = 'sushi' THEN m.price * 20
            ELSE m.price *10
        END
    ) AS total_points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
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

-- Bonus question 
-- 1.one clean table with all purchases showing whether the customer was a member at the time of that purchase.
SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE 
    WHEN s.order_date >= mm.join_date THEN 'Y'
    ELSE 'N'
END AS members
FROM sales s 
LEFT JOIN members mm ON s.customer_id = mm.customer_id 
JOIN menu m ON s.product_id = m.product_id;
-- 2.
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
