-- ================================
-- CASE STUDY #5: DATA MART
-- ================================
-- SECTION 1: DATA CLEANSING STEPS
-- ================================

DROP TABLE IF EXISTS clean_weekly_sales;

CREATE TABLE clean_weekly_sales AS
SELECT
    TO_DATE(week_date, 'DD/MM/YY') AS week_date,
    EXTRACT(WEEK FROM TO_DATE(week_date, 'DD/MM/YY')) AS week_number,
    EXTRACT(MONTH FROM TO_DATE(week_date, 'DD/MM/YY')) AS month_number,
    EXTRACT(YEAR FROM TO_DATE(week_date, 'DD/MM/YY')) AS calendar_year,
    region,
    platform,
    segment,
    CASE 
        WHEN segment = 'null' THEN 'Unknown'
        WHEN RIGHT(segment, 1) = '1' THEN 'Young Adults'
        WHEN RIGHT(segment, 1) = '2' THEN 'Middle Aged'
        WHEN RIGHT(segment, 1) IN ('3', '4') THEN 'Retirees'
        ELSE 'Unknown'
    END AS age_band,
    CASE
        WHEN segment = 'null' THEN 'Unknown'
        WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
        WHEN LEFT(segment, 1) = 'F' THEN 'Families'
        ELSE 'Unknown'
    END AS demographic,
    customer_type,
    transactions,
    sales,
    ROUND(sales::NUMERIC / transactions, 2) AS avg_transaction
FROM weekly_sales;

-- ================================
-- SECTION 2: DATA EXPLORATION
-- ================================

-- What day of the week is used for each week_date value?
SELECT DISTINCT TO_CHAR(week_date, 'Day') AS day_of_week
FROM clean_weekly_sales;

-- What range of week numbers are missing from the dataset?
WITH all_weeks AS (
    SELECT GENERATE_SERIES(1, 52) AS week_number
)
SELECT aw.week_number
FROM all_weeks aw
LEFT JOIN clean_weekly_sales cws ON aw.week_number = cws.week_number
WHERE cws.week_number IS NULL;

-- Total transactions per year
SELECT 
    calendar_year,
    SUM(transactions) AS total_transactions
FROM clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

-- Total sales by region and month
SELECT 
    region,
    month_number,
    SUM(sales) AS total_sales
FROM clean_weekly_sales
GROUP BY region, month_number
ORDER BY region, month_number;

-- Total transactions per platform
SELECT 
    platform,
    SUM(transactions) AS total_transactions
FROM clean_weekly_sales
GROUP BY platform
ORDER BY total_transactions DESC;

-- Retail vs Shopify % of sales per month
WITH monthly_platform AS (
    SELECT 
        calendar_year,
        month_number,
        platform,
        SUM(sales) AS monthly_sales
    FROM clean_weekly_sales
    GROUP BY calendar_year, month_number, platform
)
SELECT 
    calendar_year,
    month_number,
    ROUND(100.0 * SUM(CASE WHEN platform = 'Retail' THEN monthly_sales ELSE 0 END) 
        / SUM(monthly_sales), 2) AS retail_pct,
    ROUND(100.0 * SUM(CASE WHEN platform = 'Shopify' THEN monthly_sales ELSE 0 END) 
        / SUM(monthly_sales), 2) AS shopify_pct
FROM monthly_platform
GROUP BY calendar_year, month_number
ORDER BY calendar_year, month_number;

-- Demographic sales % per year
WITH demo_sales AS (
    SELECT 
        calendar_year,
        demographic,
        SUM(sales) AS total_sales
    FROM clean_weekly_sales
    GROUP BY calendar_year, demographic
)
SELECT 
    calendar_year,
    demographic,
    ROUND(100.0 * total_sales / SUM(total_sales) OVER (PARTITION BY calendar_year), 2) AS pct_of_year
FROM demo_sales
ORDER BY calendar_year, pct_of_year DESC;

-- Top contributing age_band and demographic for Retail
SELECT 
    age_band,
    demographic,
    SUM(sales) AS total_sales
FROM clean_weekly_sales
WHERE platform = 'Retail'
GROUP BY age_band, demographic
ORDER BY total_sales DESC;

-- Correct average transaction size: SUM(sales)/SUM(transactions) vs AVG(avg_transaction)
SELECT 
    calendar_year,
    ROUND(AVG(avg_transaction), 2) AS naive_avg_transaction,
    ROUND(SUM(sales)::NUMERIC / SUM(transactions), 2) AS correct_avg_transaction
FROM clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

-- ================================
-- SECTION 3: BEFORE & AFTER ANALYSIS
-- ================================
-- Baseline event: 2020-06-15 (week 25), packaging change

-- 4-week window
WITH tagged AS (
    SELECT 
        CASE WHEN week_date < '2020-06-15' THEN 'Before' ELSE 'After' END AS period,
        sales
    FROM clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15'::DATE - INTERVAL '4 weeks' 
        AND '2020-06-15'::DATE + INTERVAL '4 weeks'
)
SELECT 
    SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) AS after_sales,
    ROUND(100.0 * (SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) 
        - SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END))
        / SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END), 2) AS pct_change
FROM tagged;

-- 12-week window
WITH tagged AS (
    SELECT 
        CASE WHEN week_date < '2020-06-15' THEN 'Before' ELSE 'After' END AS period,
        sales
    FROM clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15'::DATE - INTERVAL '12 weeks' 
        AND '2020-06-15'::DATE + INTERVAL '12 weeks'
)
SELECT 
    SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) AS after_sales,
    ROUND(100.0 * (SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) 
        - SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END))
        / SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END), 2) AS pct_change
FROM tagged;

-- Year-over-year comparison for the same 12-week window (rule out seasonality)
WITH tagged AS (
    SELECT 
        calendar_year,
        CASE WHEN week_date < MAKE_DATE(calendar_year, 6, 15) THEN 'Before' ELSE 'After' END AS period,
        sales
    FROM clean_weekly_sales
    WHERE week_date BETWEEN MAKE_DATE(calendar_year, 6, 15) - INTERVAL '12 weeks' 
        AND MAKE_DATE(calendar_year, 6, 15) + INTERVAL '12 weeks'
)
SELECT 
    calendar_year,
    SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) AS after_sales,
    ROUND(100.0 * (SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) 
        - SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END))
        / SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END), 2) AS pct_change
FROM tagged
GROUP BY calendar_year
ORDER BY calendar_year;

-- ================================
-- SECTION 4: BONUS - IMPACT BY BUSINESS AREA
-- ================================
-- Pattern repeated across region, platform, age_band, demographic, customer_type

-- Region
WITH tagged AS (
    SELECT 
        region,
        CASE WHEN week_date < '2020-06-15' THEN 'Before' ELSE 'After' END AS period,
        sales
    FROM clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15'::DATE - INTERVAL '12 weeks' 
        AND '2020-06-15'::DATE + INTERVAL '12 weeks'
)
SELECT 
    region,
    SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END) AS before_sales,
    SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) AS after_sales,
    ROUND(100.0 * (SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) 
        - SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END))
        / SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END), 2) AS pct_change
FROM tagged
GROUP BY region
ORDER BY pct_change ASC;

-- Platform
WITH tagged AS (
    SELECT 
        platform,
        CASE WHEN week_date < '2020-06-15' THEN 'Before' ELSE 'After' END AS period,
        sales
    FROM clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15'::DATE - INTERVAL '12 weeks' 
        AND '2020-06-15'::DATE + INTERVAL '12 weeks'
)
SELECT 
    platform,
    ROUND(100.0 * (SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) 
        - SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END))
        / SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END), 2) AS pct_change
FROM tagged
GROUP BY platform
ORDER BY pct_change ASC;

-- Age Band
WITH tagged AS (
    SELECT 
        age_band,
        CASE WHEN week_date < '2020-06-15' THEN 'Before' ELSE 'After' END AS period,
        sales
    FROM clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15'::DATE - INTERVAL '12 weeks' 
        AND '2020-06-15'::DATE + INTERVAL '12 weeks'
)
SELECT 
    age_band,
    ROUND(100.0 * (SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) 
        - SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END))
        / SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END), 2) AS pct_change
FROM tagged
GROUP BY age_band
ORDER BY pct_change ASC;

-- Demographic
WITH tagged AS (
    SELECT 
        demographic,
        CASE WHEN week_date < '2020-06-15' THEN 'Before' ELSE 'After' END AS period,
        sales
    FROM clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15'::DATE - INTERVAL '12 weeks' 
        AND '2020-06-15'::DATE + INTERVAL '12 weeks'
)
SELECT 
    demographic,
    ROUND(100.0 * (SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) 
        - SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END))
        / SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END), 2) AS pct_change
FROM tagged
GROUP BY demographic
ORDER BY pct_change ASC;

-- Customer Type
WITH tagged AS (
    SELECT 
        customer_type,
        CASE WHEN week_date < '2020-06-15' THEN 'Before' ELSE 'After' END AS period,
        sales
    FROM clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15'::DATE - INTERVAL '12 weeks' 
        AND '2020-06-15'::DATE + INTERVAL '12 weeks'
)
SELECT 
    customer_type,
    ROUND(100.0 * (SUM(CASE WHEN period = 'After' THEN sales ELSE 0 END) 
        - SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END))
        / SUM(CASE WHEN period = 'Before' THEN sales ELSE 0 END), 2) AS pct_change
FROM tagged
GROUP BY customer_type
ORDER BY pct_change ASC;
