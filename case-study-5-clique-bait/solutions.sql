-- ================================
-- CASE STUDY #6: CLIQUE BAIT
-- ================================
-- SECTION 2: DIGITAL ANALYSIS
-- ================================

-- How many users are there?
SELECT COUNT(DISTINCT user_id) AS total_users
FROM clique_bait.users;

-- How many cookies does each user have on average?
WITH cookie_count AS (
    SELECT 
        user_id,
        COUNT(cookie_id) AS total_cookies
    FROM clique_bait.users
    GROUP BY user_id
)
SELECT ROUND(AVG(total_cookies), 2) AS avg_cookies_per_user
FROM cookie_count;

-- What is the unique number of visits by all users per month?
SELECT 
    EXTRACT(MONTH FROM event_time) AS month,
    COUNT(DISTINCT visit_id) AS unique_visits
FROM clique_bait.events
GROUP BY EXTRACT(MONTH FROM event_time)
ORDER BY month;

-- What is the number of events for each event type?
SELECT 
    ei.event_name,
    COUNT(*) AS event_count
FROM clique_bait.events e
JOIN clique_bait.event_identifier ei ON e.event_type = ei.event_type
GROUP BY ei.event_name
ORDER BY event_count DESC;

-- What is the percentage of visits which have a purchase event?
WITH purchase_visits AS (
    SELECT COUNT(DISTINCT visit_id) AS purchase_count
    FROM clique_bait.events
    WHERE event_type = 3
),
all_visits AS (
    SELECT COUNT(DISTINCT visit_id) AS total_count
    FROM clique_bait.events
)
SELECT 
    ROUND(100.0 * purchase_count / total_count, 2) AS pct_purchase_visits
FROM purchase_visits, all_visits;

-- What is the percentage of visits which view the checkout page but do not have a purchase event?
SELECT 
    ROUND(100.0 * COUNT(DISTINCT visit_id) / 
        (SELECT COUNT(DISTINCT visit_id) FROM clique_bait.events), 2) AS pct_checkout_no_purchase
FROM clique_bait.events
WHERE page_id = 12
AND visit_id NOT IN (
    SELECT DISTINCT visit_id 
    FROM clique_bait.events 
    WHERE event_type = 3
);

-- What are the top 3 pages by number of views?
SELECT 
    ph.page_name,
    COUNT(*) AS view_count
FROM clique_bait.events e
JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
WHERE e.event_type = 1
GROUP BY ph.page_name
ORDER BY view_count DESC
LIMIT 3;

-- What is the number of views and cart adds for each product category?
SELECT 
    ph.product_category,
    SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS views,
    SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_adds
FROM clique_bait.events e
JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
WHERE ph.product_category IS NOT NULL
GROUP BY ph.product_category
ORDER BY views DESC;

-- What are the top 3 products by purchases?
SELECT 
    ph.page_name AS product_name,
    COUNT(*) AS purchases
FROM clique_bait.events e
JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
WHERE e.event_type = 2
AND e.visit_id IN (
    SELECT DISTINCT visit_id 
    FROM clique_bait.events 
    WHERE event_type = 3
)
AND ph.product_id IS NOT NULL
GROUP BY ph.page_name
ORDER BY purchases DESC
LIMIT 3;

-- ================================
-- SECTION 3: PRODUCT FUNNEL ANALYSIS
-- ================================

-- Product level funnel table
CREATE TABLE clique_bait.product_funnel AS
WITH product_stats AS (
    SELECT 
        ph.page_name AS product_name,
        SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS views,
        SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_adds,
        SUM(CASE WHEN e.event_type = 2 
            AND e.visit_id NOT IN (
                SELECT DISTINCT visit_id FROM clique_bait.events WHERE event_type = 3
            ) THEN 1 ELSE 0 END) AS abandoned,
        SUM(CASE WHEN e.event_type = 2 
            AND e.visit_id IN (
                SELECT DISTINCT visit_id FROM clique_bait.events WHERE event_type = 3
            ) THEN 1 ELSE 0 END) AS purchases
    FROM clique_bait.events e
    JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
    WHERE ph.product_id IS NOT NULL
    GROUP BY ph.page_name
)
SELECT * FROM product_stats;

-- Category level funnel table
CREATE TABLE clique_bait.category_funnel AS
WITH category_stats AS (
    SELECT 
        ph.product_category,
        SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS views,
        SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_adds,
        SUM(CASE WHEN e.event_type = 2 
            AND e.visit_id NOT IN (
                SELECT DISTINCT visit_id FROM clique_bait.events WHERE event_type = 3
            ) THEN 1 ELSE 0 END) AS abandoned,
        SUM(CASE WHEN e.event_type = 2 
            AND e.visit_id IN (
                SELECT DISTINCT visit_id FROM clique_bait.events WHERE event_type = 3
            ) THEN 1 ELSE 0 END) AS purchases
    FROM clique_bait.events e
    JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
    WHERE ph.product_id IS NOT NULL
    GROUP BY ph.product_category
)
SELECT * FROM category_stats;

SELECT product_name, views FROM clique_bait.product_funnel ORDER BY views DESC LIMIT 1;
SELECT product_name, cart_adds FROM clique_bait.product_funnel ORDER BY cart_adds DESC LIMIT 1;
SELECT product_name, purchases FROM clique_bait.product_funnel ORDER BY purchases DESC LIMIT 1;

-- Q5: Highest view to purchase percentage
SELECT 
    product_name,
    ROUND(100.0 * purchases / views, 2) AS view_to_purchase_pct
FROM clique_bait.product_funnel
ORDER BY view_to_purchase_pct DESC
LIMIT 1;

-- Q6: Average conversion rate view to cart add
SELECT 
    ROUND(AVG(100.0 * cart_adds / views), 2) AS avg_view_to_cart_pct
FROM clique_bait.product_funnel;

-- Q7: Average conversion rate cart add to purchase
SELECT 
    ROUND(AVG(100.0 * purchases / cart_adds), 2) AS avg_cart_to_purchase_pct
FROM clique_bait.product_funnel;

-- section C 
CREATE TABLE clique_bait.campaign_analysis AS
WITH visit_summary AS (
    SELECT 
        u.user_id,
        e.visit_id,
        MIN(e.event_time) AS visit_start_time,
        SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS page_views,
        SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_adds,
        MAX(CASE WHEN e.event_type = 3 THEN 1 ELSE 0 END) AS purchase,
        SUM(CASE WHEN e.event_type = 4 THEN 1 ELSE 0 END) AS impression,
        SUM(CASE WHEN e.event_type = 5 THEN 1 ELSE 0 END) AS click,
        STRING_AGG(ph.page_name, ', ' ORDER BY e.sequence_number) 
            FILTER (WHERE e.event_type = 2) AS cart_products
    FROM clique_bait.events e
    JOIN clique_bait.users u ON e.cookie_id = u.cookie_id
    JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
    GROUP BY u.user_id, e.visit_id
)
SELECT 
    vs.user_id,
    vs.visit_id,
    vs.visit_start_time,
    vs.page_views,
    vs.cart_adds,
    vs.purchase,
    ci.campaign_name,
    vs.impression,
    vs.click,
    vs.cart_products
FROM visit_summary vs
LEFT JOIN clique_bait.campaign_identifier ci 
    ON vs.visit_start_time BETWEEN ci.start_date AND ci.end_date
ORDER BY vs.user_id, vs.visit_start_time;

-- Insight 1: Purchase rate by campaign
SELECT 
    COALESCE(campaign_name, 'No Campaign') AS campaign,
    COUNT(visit_id) AS total_visits,
    SUM(purchase) AS purchases,
    ROUND(100.0 * SUM(purchase) / COUNT(visit_id), 2) AS purchase_rate
FROM clique_bait.campaign_analysis
GROUP BY campaign_name
ORDER BY purchase_rate DESC;

-- Insight 2: Impact of ad impression on purchase rate
SELECT 
    CASE WHEN impression > 0 THEN 'Saw Impression' ELSE 'No Impression' END AS impression_group,
    COUNT(visit_id) AS total_visits,
    SUM(purchase) AS purchases,
    ROUND(100.0 * SUM(purchase) / COUNT(visit_id), 2) AS purchase_rate
FROM clique_bait.campaign_analysis
GROUP BY impression_group;

-- Insight 3: Impact of clicking ad vs just seeing it
SELECT 
    CASE 
        WHEN click > 0 THEN 'Clicked Ad'
        WHEN impression > 0 THEN 'Saw Ad Only'
        ELSE 'No Ad'
    END AS engagement_group,
    COUNT(visit_id) AS total_visits,
    SUM(purchase) AS purchases,
    ROUND(100.0 * SUM(purchase) / COUNT(visit_id), 2) AS purchase_rate
FROM clique_bait.campaign_analysis
GROUP BY engagement_group
ORDER BY purchase_rate DESC;

-- Insight 4: Average page views and cart adds by purchase outcome
SELECT 
    CASE WHEN purchase = 1 THEN 'Purchased' ELSE 'Did Not Purchase' END AS outcome,
    ROUND(AVG(page_views), 2) AS avg_page_views,
    ROUND(AVG(cart_adds), 2) AS avg_cart_adds
FROM clique_bait.campaign_analysis
GROUP BY outcome;

-- Insight 5: Most visited campaign period by unique users
SELECT 
    COALESCE(campaign_name, 'No Campaign') AS campaign,
    COUNT(DISTINCT user_id) AS unique_users,
    ROUND(100.0 * SUM(purchase) / COUNT(visit_id), 2) AS purchase_rate
FROM clique_bait.campaign_analysis
GROUP BY campaign_name
ORDER BY unique_users DESC;
