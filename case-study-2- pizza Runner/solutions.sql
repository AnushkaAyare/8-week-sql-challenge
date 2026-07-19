-- ================================
-- CASE STUDY #2: PIZZA RUNNER
-- ================================

-- ================================
-- DATA CLEANING
-- ================================

CREATE TEMP TABLE pizza_recipes_cleaned AS
SELECT
    pizza_id,
    UNNEST(STRING_TO_ARRAY(toppings, ', '))::INTEGER AS topping_id
FROM pizza_recipes;

CREATE TEMP TABLE customer_orders_cleaned AS
SELECT
    order_id,
    customer_id,
    pizza_id,
    CASE
        WHEN exclusions = 'null' THEN NULL
        WHEN exclusions = 'NaN' THEN NULL
        WHEN exclusions = '' THEN NULL
        ELSE exclusions
    END AS exclusions,
    CASE
        WHEN extras = 'null' THEN NULL
        WHEN extras = 'NaN' THEN NULL
        WHEN extras = '' THEN NULL
        ELSE extras
    END AS extras,
    order_time
FROM customer_orders;

CREATE TEMP TABLE runner_orders_cleaned AS
SELECT
    order_id,
    runner_id,
    CAST(
        CASE WHEN pickup_time = 'null' THEN NULL
        ELSE pickup_time
        END
    AS TIMESTAMP) AS pickup_time,
    CAST(
        CASE WHEN distance = 'null' THEN NULL
        ELSE TRIM(REPLACE(distance, 'km', ''))
        END
    AS DECIMAL) AS distance,
    CAST(
        CASE WHEN duration = 'null' THEN NULL
        ELSE TRIM(REPLACE(REPLACE(REPLACE(duration, 'minutes', ''), 'mins', ''), 'minute', ''))
        END
    AS INT) AS duration,
    CASE
        WHEN cancellation = 'null' THEN NULL
        WHEN cancellation = 'NaN' THEN NULL
        WHEN cancellation = '' THEN NULL
        ELSE cancellation
    END AS cancellation
FROM runner_orders;
-- Insight: source tables had 3 different NULL formats ('null' string,
-- 'NaN' string, empty string) plus units embedded in numeric fields
-- (e.g. "20km"). Cleaning into temp tables upfront avoids repeating this
-- logic in every downstream query.

-- ================================
-- SECTION A: PIZZA METRICS
-- ================================

-- A1: How many pizzas were ordered?
SELECT COUNT(order_id) AS total_pizza_ordered
FROM customer_orders_cleaned;
-- Insight: 14 pizzas ordered in total -- baseline volume metric.

-- A2: How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS unique_orders
FROM customer_orders_cleaned;
-- Insight: 10 unique orders for 14 pizzas -- average 1.4 pizzas/order.

-- A3: How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(order_id) AS successful_deliveries
FROM runner_orders_cleaned
WHERE cancellation IS NULL
GROUP BY runner_id;
-- Insight: Runner 1 delivered the most (4) -- uneven distribution worth
-- investigating before scaling the runner network.

-- A4: How many of each type of pizza was delivered?
SELECT c.pizza_id, p.pizza_name, COUNT(c.pizza_id) AS total_delivered
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id = r.order_id
JOIN pizza_names p ON c.pizza_id = p.pizza_id
WHERE r.cancellation IS NULL
GROUP BY c.pizza_id, p.pizza_name;
-- Insight: Meatlovers dominated (9 vs 3 Vegetarian) -- inventory
-- purchasing should reflect this ratio.

-- A5: How many Vegetarian and Meatlovers were ordered by each customer?
SELECT c.customer_id, p.pizza_name, COUNT(p.pizza_id) AS total_ordered
FROM customer_orders_cleaned c
JOIN pizza_names p ON c.pizza_id = p.pizza_id
GROUP BY c.customer_id, p.pizza_name;
-- Insight: Customer 103 ordered the most (4 total) -- natural loyalty
-- program target.

-- A6: What was the maximum number of pizzas delivered in a single order?
SELECT COUNT(c.pizza_id) AS maximum_number_of_pizzas
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY c.order_id
ORDER BY COUNT(c.pizza_id) DESC
LIMIT 1;
-- Insight: Maximum 3 pizzas in a single order -- sets a minimum kitchen
-- capacity benchmark.

-- A7: For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT
    c.customer_id,
    SUM(CASE WHEN c.exclusions IS NOT NULL OR c.extras IS NOT NULL THEN 1 ELSE 0 END) AS with_changes,
    SUM(CASE WHEN c.exclusions IS NULL AND c.extras IS NULL THEN 1 ELSE 0 END) AS no_changes
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY c.customer_id;
-- Insight: Customers 104 and 105 requested the most changes -- higher
-- customisation likely means longer prep time for their orders.

-- A8: How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(c.order_id)
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id = r.order_id
WHERE cancellation IS NULL AND exclusions IS NOT NULL AND extras IS NOT NULL;
-- Insight: Only 1 pizza had both -- fully customised orders are rare
-- enough to not need a separate workflow, just a QC flag.

-- A9: What was the total volume of pizzas ordered for each hour of the day?
SELECT EXTRACT(HOUR FROM order_time) AS hour, COUNT(order_id) AS total_pizzas
FROM customer_orders_cleaned
GROUP BY EXTRACT(HOUR FROM order_time)
ORDER BY hour;
-- Insight: Peak ordering at 18:00 and 23:00 -- runner scheduling should
-- cluster around these windows.

-- A10: What was the volume of orders for each day of the week?
SELECT TO_CHAR(order_time, 'Day') AS day, COUNT(order_id) AS total_pizzas
FROM customer_orders_cleaned
GROUP BY TO_CHAR(order_time, 'Day')
ORDER BY day;
-- Insight: Wednesday and Saturday busiest -- staffing/prep should peak
-- on these days.

-- ================================
-- SECTION B: RUNNER AND CUSTOMER EXPERIENCE
-- ================================

-- B1: How many runners signed up for each 1-week period? (week starts 2021-01-01)
SELECT
    FLOOR((registration_date - '2021-01-01') / 7) + 1 AS week_number,
    COUNT(runner_id) AS runners_signed_up
FROM runners
GROUP BY week_number;
-- Insight: Recruitment slowing after week 1 -- could become a bottleneck
-- if order volume grows.

-- B2: What was the average time in minutes it took for each runner to arrive at HQ to pick up the order?
SELECT r.runner_id,
    ROUND(AVG(EXTRACT(EPOCH FROM (r.pickup_time - c.order_time)) / 60)) AS average_time
FROM runner_orders_cleaned r
JOIN customer_orders_cleaned c ON r.order_id = c.order_id
WHERE r.cancellation IS NULL
GROUP BY r.runner_id;
-- Insight: Runner 1 averages 14 mins -- this includes kitchen prep time,
-- so a slow average may reflect the kitchen, not the runner.

-- B3: Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH order_details AS (
    SELECT
        c.order_id,
        COUNT(c.pizza_id) AS pizza_count,
        MAX(c.order_time) AS order_time,
        MAX(r.pickup_time) AS pickup_time
    FROM customer_orders_cleaned c
    JOIN runner_orders_cleaned r ON c.order_id = r.order_id
    WHERE r.cancellation IS NULL
    GROUP BY c.order_id
)
SELECT
    pizza_count,
    ROUND(EXTRACT(EPOCH FROM (pickup_time - order_time)) / 60) AS prep_time_mins
FROM order_details
ORDER BY pizza_count;
-- Insight: Clear linear trend (~12 min/pizza, roughly) -- multi-pizza
-- orders should trigger earlier runner dispatch.

-- B4: What was the average distance travelled for each customer?
SELECT c.customer_id,
    ROUND(AVG(r.distance)) AS avg_distance_km
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id = r.order_id
GROUP BY customer_id;
-- Insight: Customer 105 averages 25km per delivery, far above others --
-- at $0.30/km runner cost, that's ~$7.50 in runner fees alone per order.

-- B5: What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration) - MIN(duration) AS difference
FROM runner_orders_cleaned;
-- Insight: 30-minute range between fastest and slowest delivery -- worth
-- investigating whether distance or individual runner performance drives it.

-- B6: What was the average speed for each runner for each delivery, and do you notice any trend?
SELECT runner_id, order_id,
    ROUND(AVG(distance / (duration / 60.0))) AS avg_speed_kmh
FROM runner_orders_cleaned
WHERE cancellation IS NULL
GROUP BY runner_id, order_id;
-- Insight: Runner 2 shows highly inconsistent speed across deliveries --
-- worth checking for route or data-quality issues.

-- B7: What is the successful delivery percentage for each runner?
SELECT runner_id,
    ROUND(100.0 * COUNT(CASE WHEN cancellation IS NULL THEN 1 END) / COUNT(order_id)) AS success_percentage
FROM runner_orders_cleaned
GROUP BY runner_id;
-- Insight: Runner 1: 100%, Runner 2: 75%, Runner 3: 50% -- sample size is
-- small, so Runner 3's rate needs monitoring, not a conclusion yet.

-- ================================
-- SECTION C: INGREDIENT OPTIMISATION
-- ================================

-- C1: What are the standard ingredients for each pizza?
SELECT n.pizza_name, t.topping_name
FROM pizza_recipes_cleaned r
JOIN pizza_names n ON r.pizza_id = n.pizza_id
JOIN pizza_toppings t ON r.topping_id = t.topping_id
ORDER BY n.pizza_name, t.topping_name;
-- Insight: Meatlovers has 8 ingredients vs Vegetarian's 6 -- more
-- supply-chain exposure for Meatlovers given its higher order volume.

-- C2: What was the most commonly added extra?
WITH extras_cleaned AS (
    SELECT UNNEST(STRING_TO_ARRAY(extras, ', '))::INTEGER AS extra_topping_id
    FROM customer_orders_cleaned
    WHERE extras IS NOT NULL
)
SELECT t.topping_name, COUNT(*) AS times_added
FROM extras_cleaned e
JOIN pizza_toppings t ON e.extra_topping_id = t.topping_id
GROUP BY t.topping_name
ORDER BY times_added DESC
LIMIT 1;
-- Insight: Bacon is the most added extra -- a prompted upsell at
-- checkout is a low-effort revenue lever, demand is already organic.

-- C3: What was the most common exclusion?
WITH exclusions_cleaned AS (
    SELECT UNNEST(STRING_TO_ARRAY(exclusions, ', '))::INTEGER AS exclusions_topping_id
    FROM customer_orders_cleaned
    WHERE exclusions IS NOT NULL
)
SELECT t.topping_name, COUNT(*) AS times_added
FROM exclusions_cleaned e
JOIN pizza_toppings t ON e.exclusions_topping_id = t.topping_id
GROUP BY t.topping_name
ORDER BY times_added DESC
LIMIT 1;
-- Insight: Cheese is the most excluded ingredient -- a "no cheese"
-- variant could reduce order complexity for the kitchen.

-- C4: Generate an order item description for each record in customer_orders.
WITH exclusion_names AS (
    SELECT
        c.order_id, c.pizza_id,
        STRING_AGG(t.topping_name, ', ') AS exclusion_list
    FROM customer_orders_cleaned c,
    UNNEST(STRING_TO_ARRAY(c.exclusions, ', ')) AS excl_id
    JOIN pizza_toppings t ON t.topping_id = CAST(TRIM(excl_id) AS INTEGER)
    WHERE c.exclusions IS NOT NULL
    GROUP BY c.order_id, c.pizza_id
),
extra_names AS (
    SELECT
        c.order_id, c.pizza_id,
        STRING_AGG(t.topping_name, ', ') AS extra_list
    FROM customer_orders_cleaned c,
    UNNEST(STRING_TO_ARRAY(c.extras, ', ')) AS extr_id
    JOIN pizza_toppings t ON t.topping_id = CAST(TRIM(extr_id) AS INTEGER)
    WHERE c.extras IS NOT NULL
    GROUP BY c.order_id, c.pizza_id
)
SELECT
    c.order_id, c.customer_id, c.pizza_id,
    n.pizza_name ||
    CASE WHEN e.exclusion_list IS NOT NULL THEN ' - Exclude ' || e.exclusion_list ELSE '' END ||
    CASE WHEN x.extra_list IS NOT NULL THEN ' - Extra ' || x.extra_list ELSE '' END AS order_item
FROM customer_orders_cleaned c
JOIN pizza_names n ON c.pizza_id = n.pizza_id
LEFT JOIN exclusion_names e ON c.order_id = e.order_id AND c.pizza_id = e.pizza_id
LEFT JOIN extra_names x ON c.order_id = x.order_id AND c.pizza_id = x.pizza_id
ORDER BY c.order_id;
-- Insight: order labels built dynamically -- scales to any number of
-- toppings without hardcoding; same pattern works for kitchen tickets.

-- C5: Generate an alphabetically ordered, comma-separated ingredient list for each pizza order, with a 2x prefix for doubled ingredients.
WITH base_ingredients AS (
    SELECT order_id, pizza_id, topping_id
    FROM customer_orders_cleaned c
    JOIN pizza_recipes_cleaned p ON c.pizza_id = p.pizza_id
),
extra_ingredients AS (
    SELECT order_id, pizza_id,
        CAST(TRIM(UNNEST(STRING_TO_ARRAY(extras, ', '))) AS INTEGER) AS topping_id
    FROM customer_orders_cleaned
    WHERE extras IS NOT NULL
),
all_ingredients AS (
    SELECT * FROM base_ingredients
    UNION ALL
    SELECT * FROM extra_ingredients
),
ingredient_counts AS (
    SELECT a.order_id, a.pizza_id, t.topping_name, COUNT(*) AS cnt
    FROM all_ingredients a
    JOIN pizza_toppings t ON a.topping_id = t.topping_id
    GROUP BY a.order_id, a.pizza_id, t.topping_name
)
SELECT order_id, pizza_id,
    STRING_AGG(
        CASE WHEN cnt > 1 THEN '2x' || topping_name ELSE topping_name END,
        ', ' ORDER BY topping_name
    ) AS ingredient_list
FROM ingredient_counts
GROUP BY order_id, pizza_id
ORDER BY order_id;
-- Insight: the 2x prefix works by counting ingredient appearances --
-- base recipe + extras combine before labelling, cleaner than detecting
-- extras separately after the fact.

-- C6: What is the total quantity of each ingredient used in all delivered pizzas, sorted by most frequent first?
WITH base_ingredients AS (
    SELECT c.order_id, c.pizza_id, p.topping_id
    FROM customer_orders_cleaned c
    JOIN pizza_recipes_cleaned p ON c.pizza_id = p.pizza_id
    JOIN runner_orders_cleaned ro ON c.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
),
extra_ingredients AS (
    SELECT c.order_id, c.pizza_id,
        CAST(TRIM(UNNEST(STRING_TO_ARRAY(c.extras, ', '))) AS INTEGER) AS topping_id
    FROM customer_orders_cleaned c
    JOIN runner_orders_cleaned ro ON c.order_id = ro.order_id
    WHERE ro.cancellation IS NULL AND c.extras IS NOT NULL
),
all_ingredients AS (
    SELECT * FROM base_ingredients
    UNION ALL
    SELECT * FROM extra_ingredients
)
SELECT t.topping_name, COUNT(*) AS total_quantity
FROM all_ingredients a
JOIN pizza_toppings t ON a.topping_id = t.topping_id
GROUP BY t.topping_name
ORDER BY total_quantity DESC;
-- Insight: Bacon appears in almost every delivered order -- highest
-- reorder priority and buffer stock of any ingredient.

-- ================================
-- SECTION D: PRICING AND RATINGS
-- ================================

-- D1: If Meat Lovers costs $12 and Vegetarian $10, no charge for changes, how much has Pizza Runner made (no delivery fees)?
SELECT SUM(
    CASE WHEN pizza_id = 1 THEN 12
         WHEN pizza_id = 2 THEN 10
    END
) AS money_made
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id = r.order_id
WHERE cancellation IS NULL;
-- Insight: $138 total revenue -- the floor before extras/delivery fees.

-- D2: What if there was an additional $1 charge for any pizza extras?
SELECT SUM(
    CASE WHEN pizza_id = 1 THEN 12
         WHEN pizza_id = 2 THEN 10
    END
    +
    CASE WHEN extras IS NULL THEN 0
         ELSE ARRAY_LENGTH(STRING_TO_ARRAY(extras, ', '), 1)
    END
) AS money_made
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id = r.order_id
WHERE cancellation IS NULL;
-- Insight: $142 with the extras charge -- only $4 more than base; extras
-- pricing contributes minimally at current volumes.

-- D3: Design a runner ratings system (1-5) and insert sample data for successful orders.
CREATE TABLE runner_ratings (
    rating_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    runner_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    rated_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO runner_ratings (order_id, runner_id, customer_id, rating)
VALUES
    (1, 1, 101, 4),
    (2, 1, 101, 5),
    (3, 1, 102, 3),
    (4, 2, 103, 4),
    (5, 3, 104, 5),
    (7, 2, 105, 3),
    (8, 2, 102, 4),
    (10, 1, 104, 5);
-- Insight: CHECK constraint enforces valid rating range at the database
-- level, not in application code -- data integrity belongs in the schema.

-- D4: Using the ratings table, join all information together for successful deliveries.
WITH pizza_count AS (
    SELECT order_id, COUNT(pizza_id) AS total_pizzas
    FROM customer_orders_cleaned
    GROUP BY order_id
)
SELECT
    c.customer_id, r.order_id, r.runner_id, rt.rating,
    c.order_time, r.pickup_time,
    ROUND(EXTRACT(EPOCH FROM (r.pickup_time - c.order_time)) / 60) AS time_between_order_and_pickup,
    r.duration AS delivery_duration,
    ROUND(r.distance / (r.duration / 60.0), 1) AS avg_speed,
    p.total_pizzas
FROM runner_orders_cleaned r
JOIN (
    SELECT DISTINCT order_id, customer_id, order_time
    FROM customer_orders_cleaned
) c ON r.order_id = c.order_id
JOIN runner_ratings rt ON r.order_id = rt.order_id
JOIN pizza_count p ON r.order_id = p.order_id
WHERE r.cancellation IS NULL;
-- Insight: Runner 1 consistently shows fastest pickup and highest
-- ratings -- foundation for a runner performance scorecard.

-- D5: If Meat Lovers is $12, Vegetarian $10 fixed, no cost for extras, and each runner is paid $0.30/km, how much profit is left after deliveries?
WITH order_revenue AS (
    SELECT
        r.order_id,
        SUM(CASE WHEN c.pizza_id = 1 THEN 12 WHEN c.pizza_id = 2 THEN 10 END) AS revenue,
        r.distance * 0.30 AS runner_cost
    FROM runner_orders_cleaned r
    JOIN customer_orders_cleaned c ON r.order_id = c.order_id
    WHERE r.cancellation IS NULL
    GROUP BY r.order_id, r.distance
)
SELECT ROUND(SUM(revenue) - SUM(runner_cost)) AS profit
FROM order_revenue;
-- Insight: $94.44 net profit after runner costs -- runner costs consume
-- roughly 32% of gross revenue.

-- ================================
-- SECTION E: BONUS QUESTIONS
-- ================================

-- E1: If Danny wants to expand his range of pizzas, how would this impact the existing data design? Demonstrate with a new Supreme pizza.
INSERT INTO pizza_names (pizza_id, pizza_name)
VALUES (3, 'Supreme');

INSERT INTO pizza_recipes (pizza_id, toppings)
VALUES (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');
-- Insight: adding a new pizza requires two INSERT statements -- the
-- existing schema handles new menu items cleanly with no structural change.
