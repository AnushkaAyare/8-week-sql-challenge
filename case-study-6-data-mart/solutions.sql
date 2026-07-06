-- A. Data CLeaning 

CREATE TABLE data_mart.clean_weekly_sales AS
SELECT
    TO_DATE(week_date, 'DD/MM/YY') AS week_date,
    EXTRACT(WEEK FROM TO_DATE(week_date, 'DD/MM/YY')) AS week_number,
    EXTRACT(MONTH FROM TO_DATE(week_date, 'DD/MM/YY')) AS month_number,
    EXTRACT(YEAR FROM TO_DATE(week_date, 'DD/MM/YY')) AS calendar_year,
    region,
    platform,
    CASE WHEN segment = 'null' THEN 'Unknown' ELSE segment END AS segment,
    CASE 
        WHEN RIGHT(segment, 1) = '1' THEN 'Young Adults'
        WHEN RIGHT(segment, 1) = '2' THEN 'Middle Aged'
        WHEN RIGHT(segment, 1) IN ('3', '4') THEN 'Retirees'
        ELSE 'Unknown'
    END AS age_band,
    CASE 
        WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
        WHEN LEFT(segment, 1) = 'F' THEN 'Families'
        ELSE 'Unknown'
    END AS demographic,
    customer_type,
    transactions,
    sales,
    ROUND(sales::NUMERIC / transactions, 2) AS avg_transaction
FROM data_mart.weekly_sales;

-- B. Data Exploration

-- B1. What day of the week is used for each week_date value?
SELECT DISTINCT TO_CHAR(week_date, 'Day') AS day_of_week
FROM data_mart.clean_weekly_sales;

-- B2. What range of week numbers are missing from the dataset?
SELECT GENERATE_SERIES(1, 52) AS week_number;

SELECT gs.week_number
FROM GENERATE_SERIES(1, 52) AS gs(week_number)
LEFT JOIN clean_weekly_sales cws ON gs.week_number = cws.week_number
WHERE cws.week_number IS NULL
ORDER BY gs.week_number;

-- B3. How many total transactions were there for each year in the dataset?
SELECT 
    calendar_year,
    SUM(transactions) AS total_transactions
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

-- B4. What is the total sales for each region for each month?
select region ,month_number,sum(sales) as total_sales from clean_weekly_sales
group by region , month_number ;

-- B5. What is the total count of transactions for each platform
select platform, sum(transactions) as total_transactions from clean_weekly_sales group by platform;

-- B6. What is the percentage of sales for Retail vs Shopify for each month?
SELECT 
    calendar_year,
    demographic,
    SUM(sales) AS demographic_sales,
    ROUND(
        100.0 * SUM(sales) / SUM(SUM(sales)) OVER (PARTITION BY calendar_year),
        2
    ) AS pct_of_sales
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year, demographic
ORDER BY calendar_year, demographic;

-- B7. What is the percentage of sales by demographic for each year in the dataset?
SELECT 
    calendar_year,
    demographic,
    SUM(sales) AS demographic_sales,
    ROUND(
        100.0 * SUM(sales) / SUM(SUM(sales)) OVER (PARTITION BY calendar_year),
        2
    ) AS pct_of_sales
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year, demographic
ORDER BY calendar_year, demographic;

-- B8. Which age_band and demographic values contribute the most to Retail sales?
select age_band ,demographic, sum(sales) as total_sales 
from clean_weekly_sales
where platform = 'Retail' 
group by age_band,demographic
ORDER BY total_sales DESC;

-- B9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT 
    calendar_year,
    platform,
    SUM(sales) AS total_sales,
    SUM(transactions) AS total_transactions,
    ROUND(SUM(sales)::NUMERIC / SUM(transactions), 2) AS correct_avg_transaction
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year, platform
ORDER BY calendar_year, platform;

-- C. Before & After Analysis

-- Q: How do you find which week number 2020-06-15 falls in?
SELECT DISTINCT week_number 
FROM data_mart.clean_weekly_sales
WHERE week_date = '2020-06-15';

-- C1: What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
WITH before_after AS (
    SELECT 
        CASE 
            WHEN week_number BETWEEN 21 AND 24 THEN 'Before'
            WHEN week_number BETWEEN 25 AND 28 THEN 'After'
        END AS period,
        SUM(sales) AS total_sales
    FROM data_mart.clean_weekly_sales
    WHERE calendar_year = 2020
    AND week_number BETWEEN 21 AND 28
    GROUP BY period
)
SELECT
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) AS after_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) - 
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS difference,
    ROUND(100.0 * (
        SUM(CASE WHEN period = 'After' THEN total_sales END) - 
        SUM(CASE WHEN period = 'Before' THEN total_sales END)
    ) / SUM(CASE WHEN period = 'Before' THEN total_sales END), 2) AS pct_change
FROM before_after;

-- C2: What about the entire 12 weeks before and after?
WITH before_after AS (
    SELECT 
        CASE 
            WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
            WHEN week_number BETWEEN 25 AND 37 THEN 'After'
        END AS period,
        SUM(sales) AS total_sales
    FROM data_mart.clean_weekly_sales
    WHERE calendar_year = 2020
    AND week_number BETWEEN 13 AND 37
    GROUP BY period
)
SELECT
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) AS after_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) - 
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS difference,
    ROUND(100.0 * (
        SUM(CASE WHEN period = 'After' THEN total_sales END) - 
        SUM(CASE WHEN period = 'Before' THEN total_sales END)
    ) / SUM(CASE WHEN period = 'Before' THEN total_sales END), 2) AS pct_change
FROM before_after;

-- C3: How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
WITH before_after AS (
    SELECT 
        calendar_year,
        CASE 
            WHEN week_number BETWEEN 21 AND 24 THEN 'Before'
            WHEN week_number BETWEEN 25 AND 28 THEN 'After'
        END AS period,
        SUM(sales) AS total_sales
    FROM data_mart.clean_weekly_sales
    WHERE week_number BETWEEN 21 AND 28
    GROUP BY calendar_year, period
)
SELECT
    calendar_year,
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) AS after_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) - 
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS difference,
    ROUND(100.0 * (
        SUM(CASE WHEN period = 'After' THEN total_sales END) - 
        SUM(CASE WHEN period = 'Before' THEN total_sales END)
    ) / SUM(CASE WHEN period = 'Before' THEN total_sales END), 2) AS pct_change
FROM before_after
GROUP BY calendar_year
ORDER BY calendar_year; 

-- D. Bonus Question

-- D1: Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?
WITH before_after AS (
    SELECT 
        region,
        CASE 
            WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
            WHEN week_number BETWEEN 25 AND 37 THEN 'After'
        END AS period,
        SUM(sales) AS total_sales
    FROM data_mart.clean_weekly_sales
    WHERE calendar_year = 2020
    AND week_number BETWEEN 13 AND 37
    GROUP BY region, period
)
SELECT
    region,
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) AS after_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) - 
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS difference,
    ROUND(100.0 * (
        SUM(CASE WHEN period = 'After' THEN total_sales END) - 
        SUM(CASE WHEN period = 'Before' THEN total_sales END)
    ) / SUM(CASE WHEN period = 'Before' THEN total_sales END), 2) AS pct_change
FROM before_after
GROUP BY region
ORDER BY pct_change ASC;

WITH before_after AS (
    SELECT 
        platform,
        CASE 
            WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
            WHEN week_number BETWEEN 25 AND 37 THEN 'After'
        END AS period,
        SUM(sales) AS total_sales
    FROM data_mart.clean_weekly_sales
    WHERE calendar_year = 2020
    AND week_number BETWEEN 13 AND 37
    GROUP BY platform, period
)
SELECT
    platform,
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) AS after_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) - 
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS difference,
    ROUND(100.0 * (
        SUM(CASE WHEN period = 'After' THEN total_sales END) - 
        SUM(CASE WHEN period = 'Before' THEN total_sales END)
    ) / SUM(CASE WHEN period = 'Before' THEN total_sales END), 2) AS pct_change
FROM before_after
GROUP BY platform
ORDER BY pct_change ASC;

WITH before_after AS (
    SELECT 
        age_band,
        CASE 
            WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
            WHEN week_number BETWEEN 25 AND 37 THEN 'After'
        END AS period,
        SUM(sales) AS total_sales
    FROM data_mart.clean_weekly_sales
    WHERE calendar_year = 2020
    AND week_number BETWEEN 13 AND 37
    GROUP BY age_band, period
)
SELECT
    age_band,
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) AS after_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) - 
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS difference,
    ROUND(100.0 * (
        SUM(CASE WHEN period = 'After' THEN total_sales END) - 
        SUM(CASE WHEN period = 'Before' THEN total_sales END)
    ) / SUM(CASE WHEN period = 'Before' THEN total_sales END), 2) AS pct_change
FROM before_after
GROUP BY age_band
ORDER BY pct_change ASC;

WITH before_after AS (
    SELECT 
        demographic,
        CASE 
            WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
            WHEN week_number BETWEEN 25 AND 37 THEN 'After'
        END AS period,
        SUM(sales) AS total_sales
    FROM data_mart.clean_weekly_sales
    WHERE calendar_year = 2020
    AND week_number BETWEEN 13 AND 37
    GROUP BY demographic, period
)
SELECT
    demographic,
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) AS after_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) - 
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS difference,
    ROUND(100.0 * (
        SUM(CASE WHEN period = 'After' THEN total_sales END) - 
        SUM(CASE WHEN period = 'Before' THEN total_sales END)
    ) / SUM(CASE WHEN period = 'Before' THEN total_sales END), 2) AS pct_change
FROM before_after
GROUP BY demographic
ORDER BY pct_change ASC;

WITH before_after AS (
    SELECT 
        customer_type,
        CASE 
            WHEN week_number BETWEEN 13 AND 24 THEN 'Before'
            WHEN week_number BETWEEN 25 AND 37 THEN 'After'
        END AS period,
        SUM(sales) AS total_sales
    FROM data_mart.clean_weekly_sales
    WHERE calendar_year = 2020
    AND week_number BETWEEN 13 AND 37
    GROUP BY customer_type, period
)
SELECT
    customer_type,
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) AS after_sales,
    SUM(CASE WHEN period = 'After' THEN total_sales END) - 
    SUM(CASE WHEN period = 'Before' THEN total_sales END) AS difference,
    ROUND(100.0 * (
        SUM(CASE WHEN period = 'After' THEN total_sales END) - 
        SUM(CASE WHEN period = 'Before' THEN total_sales END)
    ) / SUM(CASE WHEN period = 'Before' THEN total_sales END), 2) AS pct_change
FROM before_after
GROUP BY customer_type
ORDER BY pct_change ASC;

-- D2: Do you have any further recommendations for Danny’s team at Data Mart or any interesting insights based off this analysis?
-- 1. Pilot future changes in Europe + Shopify first — both showed positive response
-- 2. Stagger regional rollout — Asia and Oceania need extra lead time
-- 3. Lead sustainability messaging with New customers and Young Adults — most receptive
-- 4. Incentivise demographic data collection — Unknown segment is largest and most impacted
-- 5. Extend measurement window to 6 months — 12 weeks may not capture full recovery
