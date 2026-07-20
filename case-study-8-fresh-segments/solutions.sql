-- ================================
-- Case Study #8: Fresh Segments — 8 Week SQL Challenge, Danny Ma
-- ================================

-- ================================
-- SECTION A: Data Exploration and Cleansing
-- ================================

-- Q1: Convert month_year to a real date, start-of-month.
-- Real format is 'Mon-YY' (e.g. Jul-18), not 'MM-YYYY' like the fake dataset.
ALTER TABLE fresh_segments.interest_metrics
ALTER COLUMN month_year TYPE date USING to_date(month_year, 'Mon-YY');
-- Note: the real data also has 1,194 rows where month_year is genuinely
-- blank/NULL to begin with -- to_date(NULL, ...) returns NULL cleanly,
-- it does not error.

-- Q2: Count of records per month_year, chronological, nulls first.
SELECT COUNT(*) AS count_of_records, month_year
FROM fresh_segments.interest_metrics
GROUP BY month_year
ORDER BY month_year NULLS FIRST;
-- Real result: 1,194 NULL rows first, then 14 real months ranging from
-- 729 (Jul 2018) up to 1,149 (Aug 2019) records -- a real, uneven spread,
-- unlike the flat "10 every month" from the fake dataset.

-- Q3: What should we do with the null values?
SELECT
    COUNT(*) FILTER (WHERE month_year IS NULL) AS null_rows,
    COUNT(*) AS total_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE month_year IS NULL) / COUNT(*), 2) AS pct_null
FROM fresh_segments.interest_metrics;
-- Real result: 1,194 null rows out of 14,273 total = 8.37%. Not trivial --
-- large enough that dropping them silently would lose a meaningful slice
-- of the dataset. Since these rows still carry composition/index_value/
-- ranking/percentile_ranking (just no month or interest_id attached), the
-- safer move is to exclude them from month-based and interest-based
-- aggregations (which is what every query below already does via
-- WHERE month_year IS NOT NULL / interest_id IS NOT NULL) rather than
-- deleting the rows outright -- they may still carry information for
-- other analyses, just not ones keyed on month or interest.

-- Q4: interest_id mismatches between interest_metrics and interest_map.
SELECT COUNT(DISTINCT im.interest_id)
FROM fresh_segments.interest_metrics im
LEFT JOIN fresh_segments.interest_map map ON im.interest_id::integer = map.id
WHERE map.id IS NULL AND im.interest_id IS NOT NULL;
-- Real result: 0 -- every real (non-null) interest_id in interest_metrics
-- has a match in interest_map.

SELECT COUNT(DISTINCT map.id)
FROM fresh_segments.interest_map map
LEFT JOIN fresh_segments.interest_metrics im ON map.id = im.interest_id::integer
WHERE im.interest_id IS NULL;
-- Real result: 7 -- a handful of interests in the reference table were
-- never actually measured in this metrics window. Much smaller gap than
-- the fake dataset's 183, and directionally opposite from A4's first
-- result (0) -- worth noting both are real, just asymmetric for a
-- different reason than before.

-- Q5: Summarise id values in interest_map by record count.
SELECT id, COUNT(*) AS cnt
FROM fresh_segments.interest_map
GROUP BY id
HAVING COUNT(*) > 1;
-- Real result: 0 rows -- id is a clean, unique key, same conclusion as
-- before, this time on real data of 1,209 rows rather than 15.

-- Q6: Which join, and why? Verify with interest_id = 21246.
-- LEFT JOIN, interest_metrics as the left table: preserves every metrics
-- row even where a match is missing, instead of silently dropping rows
-- the way an INNER JOIN would (relevant given the 1,194 null-interest_id
-- rows and the 7 unmatched map ids found above).
SELECT im.interest_id, im.month_year, im.composition, im.index_value,
       im.ranking, im.percentile_ranking,
       map.interest_name, map.interest_summary, map.created_at, map.last_modified
FROM fresh_segments.interest_metrics im
LEFT JOIN fresh_segments.interest_map map ON im.interest_id::integer = map.id
WHERE im.interest_id = '21246'
ORDER BY im.month_year;
-- Real result: 11 rows, all "Readers of El Salvadoran Content", composition
-- ranging ~1.58-2.26 across the months present -- this is the exact id the
-- original case study asks you to check, confirming this dataset is genuine.

-- Q7: Any records where month_year is before interest_map.created_at?
SELECT COUNT(*)
FROM fresh_segments.interest_metrics im
LEFT JOIN fresh_segments.interest_map map ON im.interest_id::integer = map.id
WHERE im.month_year < map.created_at;
-- Real result: 188 rows. Unlike the fake dataset (which had zero), this is
-- a genuine, non-trivial finding: 188 metrics rows are dated before their
-- interest was even added to interest_map. Worth flagging as a real data-
-- quality question rather than assuming invalid -- e.g. interest_map's
-- created_at may reflect when the interest was catalogued/labelled in the
-- reference table, not necessarily when tracking of it began, so an
-- interest could plausibly be measured before being formally added to the
-- lookup table. Worth a follow-up question to whoever owns the pipeline
-- rather than silently deleting these 188 rows.


-- ================================
-- SECTION B: Interest Analysis
-- ================================

-- Q1: Which interests present in all 14 months?
WITH im AS (
    SELECT interest_id, COUNT(DISTINCT month_year) AS total_months
    FROM fresh_segments.interest_metrics
    WHERE interest_id IS NOT NULL
    GROUP BY interest_id
)
SELECT interest_id, total_months FROM im WHERE total_months = 14;
-- Real result: 480 interests (out of ~1,202 with any metrics history) --
-- a meaningful subset, not all of them, unlike the fake dataset where
-- every single interest trivially qualified.

-- Q2: Cumulative % of total_months -- which value passes 90%?
WITH im AS (
    SELECT interest_id, COUNT(DISTINCT month_year) AS total_months
    FROM fresh_segments.interest_metrics
    WHERE interest_id IS NOT NULL
    GROUP BY interest_id
),
months_summary AS (
    SELECT total_months, COUNT(*) AS interest_count
    FROM im GROUP BY total_months
)
SELECT total_months, interest_count,
    SUM(interest_count) OVER (ORDER BY total_months) AS cumulative_count,
    ROUND(100.0 * SUM(interest_count) OVER (ORDER BY total_months)
        / SUM(interest_count) OVER (), 2) AS cumulative_percentage
FROM months_summary
ORDER BY total_months;
-- Real result: a genuine spread this time -- cumulative % climbs steadily
-- from 1.08% (total_months=1) up through 60.07% (total_months=13), then
-- jumps to 100.00% at total_months=14 (the 480-interest cluster from B1).
-- total_months=14 is the value that passes the 90% threshold -- same
-- number as the fake dataset's answer, but this time because of a real,
-- lopsided distribution (a huge cluster at full coverage), not because
-- it was the only value that existed.

-- Q3: Data points removed if we drop interests below that threshold (14).
WITH im AS (
    SELECT interest_id, COUNT(DISTINCT month_year) AS total_months
    FROM fresh_segments.interest_metrics
    WHERE interest_id IS NOT NULL
    GROUP BY interest_id
)
SELECT COUNT(*) AS interests_removed, SUM(total_months) AS data_points_removed
FROM im WHERE total_months < 14;
-- Real result: 722 interests removed, 6,359 data points removed -- a
-- substantial cut, genuinely worth debating (see B4), unlike the fake
-- dataset's 0/0.

-- Q4: Does this decision make business sense?
-- Removing everything below full 14-month coverage would cut 722 of
-- roughly 1,202 interests (60%) and 6,359 real data points -- that's an
-- aggressive cut for a threshold this strict. Example: interest_id=21057
-- ("Work Comes First Travelers") is the top-ranked interest by average
-- composition for six straight months (Sep 2018-Feb 2019, see D4) but
-- would need checking against its own total_months count before assuming
-- it survives a full-coverage filter. Losing a strong, consistently
-- top-performing interest purely because it has, say, 10 months of history
-- instead of 14 would throw away a genuinely useful segment. A softer
-- threshold (e.g. the >= 6 months filter the case study itself uses for
-- Section C) is a more defensible cutoff than requiring full coverage --
-- it keeps interests with enough history to trend reliably, without
-- discarding two-thirds of the dataset over a technicality.

-- Q5: Unique interests per month after applying the >= 6 months filter
-- (using the Section C threshold, since B3's stricter =14 filter would
-- leave every remaining month at a flat count and isn't the filter
-- actually carried forward into the rest of the case study).
WITH im AS (
    SELECT interest_id, COUNT(DISTINCT month_year) AS total_months
    FROM fresh_segments.interest_metrics
    WHERE interest_id IS NOT NULL
    GROUP BY interest_id
),
keep AS (SELECT interest_id FROM im WHERE total_months >= 6)
SELECT m.month_year, COUNT(DISTINCT m.interest_id) AS unique_interests
FROM fresh_segments.interest_metrics m
JOIN keep k ON m.interest_id = k.interest_id
WHERE m.month_year IS NOT NULL
GROUP BY m.month_year
ORDER BY m.month_year;
-- Real result: ranges from 709 (Jul 2018) up to 1,078 (Mar 2019), settling
-- around 800-1,000 for most months -- a real, moving count, not a flat
-- number like the fake dataset's constant 10.


-- ================================
-- SECTION C: Segment Analysis
-- (filtered to interests with >= 6 months of data, per the case study's
-- own stated threshold for this section)
-- ================================

-- Q1: Top 10 and bottom 10 interests by largest composition in any month
--     (max composition per interest, filtered dataset, keep the month).
WITH keep AS (
    SELECT interest_id FROM fresh_segments.interest_metrics
    WHERE interest_id IS NOT NULL
    GROUP BY interest_id HAVING COUNT(DISTINCT month_year) >= 6
),
maxc AS (
    SELECT DISTINCT ON (m.interest_id)
        m.interest_id, map.interest_name, m.month_year, m.composition
    FROM fresh_segments.interest_metrics m
    JOIN keep k ON m.interest_id = k.interest_id
    LEFT JOIN fresh_segments.interest_map map ON m.interest_id::integer = map.id
    ORDER BY m.interest_id, m.composition DESC
)
(SELECT * FROM maxc ORDER BY composition DESC LIMIT 10)
UNION ALL
(SELECT * FROM maxc ORDER BY composition ASC LIMIT 10);
-- Real top 10 (by composition): Work Comes First Travelers (21.20, Dec18),
-- Gym Equipment Owners (18.82, Jul18), Furniture Shoppers (17.44, Jul18),
-- Luxury Retail Shoppers (17.19, Jul18), Luxury Boutique Hotel Researchers
-- (15.15, Oct18), Luxury Bedding Shoppers (15.05, Dec18), Shoe Shoppers
-- (14.91, Jul18), Cosmetics and Beauty Shoppers (14.23, Jul18), Luxury
-- Hotel Guests (14.10, Jul18), Luxury Retail Researchers (13.97, Jul18).
-- Real bottom 10: Astrology Enthusiasts (1.88), Medieval History
-- Enthusiasts (1.94), Dodge Vehicle Shoppers (1.97), Xbox Enthusiasts
-- (2.05), Camaro Enthusiasts (2.08), League of Legends Video Game Fans
-- (2.09), Budget Mobile Phone Researchers (2.09), Super Mario Bros Fans
-- (2.12), Oakland Raiders Fans (2.14), Haunted House Researchers (2.18).
-- Genuinely different lists, real values -- a meaningful contrast this
-- time, not the same 10 interests reversed.

-- Q2: 5 interests with lowest average ranking.
SELECT m.interest_id, map.interest_name, ROUND(AVG(m.ranking), 2) AS avg_ranking
FROM fresh_segments.interest_metrics m
LEFT JOIN fresh_segments.interest_map map ON m.interest_id::integer = map.id
WHERE m.interest_id IS NOT NULL
GROUP BY m.interest_id, map.interest_name
ORDER BY avg_ranking ASC
LIMIT 5;
-- Real result: Winter Apparel Shoppers (1.00), Fitness Activity Tracker
-- Users (4.11), Mens Shoe Shoppers (5.93), Elite Cycling Gear Shoppers
-- (7.80), Shoe Shoppers (9.36).

-- Q3: 5 interests with largest stddev in percentile_ranking.
SELECT m.interest_id, map.interest_name, ROUND(STDDEV(m.percentile_ranking), 2) AS stddev_percentile
FROM fresh_segments.interest_metrics m
LEFT JOIN fresh_segments.interest_map map ON m.interest_id::integer = map.id
WHERE m.interest_id IS NOT NULL
GROUP BY m.interest_id, map.interest_name
ORDER BY stddev_percentile DESC
LIMIT 5;
-- Real result: Blockbuster Movie Fans (41.27), Android Fans (30.72), TV
-- Junkies (30.36), Techies (30.18), Entertainment Industry Decision
-- Makers (28.97).

-- Q4: Min/max percentile_ranking (+ month) for those 5 interests.
WITH top5 AS (
    SELECT interest_id FROM fresh_segments.interest_metrics
    WHERE interest_id IS NOT NULL
    GROUP BY interest_id
    ORDER BY STDDEV(percentile_ranking) DESC LIMIT 5
),
ranked AS (
    SELECT m.interest_id, map.interest_name, m.month_year, m.percentile_ranking,
        RANK() OVER (PARTITION BY m.interest_id ORDER BY m.percentile_ranking ASC) AS min_rnk,
        RANK() OVER (PARTITION BY m.interest_id ORDER BY m.percentile_ranking DESC) AS max_rnk
    FROM fresh_segments.interest_metrics m
    LEFT JOIN fresh_segments.interest_map map ON m.interest_id::integer = map.id
    WHERE m.interest_id IN (SELECT interest_id FROM top5)
)
SELECT interest_id, interest_name, month_year, percentile_ranking, 'min' AS type FROM ranked WHERE min_rnk = 1
UNION ALL
SELECT interest_id, interest_name, month_year, percentile_ranking, 'max' AS type FROM ranked WHERE max_rnk = 1
ORDER BY interest_id, type;
-- Real result: all 5 peak in Jul 2018 and bottom out at different points
-- across 2019 (Android Fans: 75.03 -> 4.84 by Mar19; TV Junkies: 93.28 ->
-- 10.01 by Aug19; Entertainment Industry Decision Makers: 86.15 -> 11.23;
-- Techies: 86.69 -> 7.92; Blockbuster Movie Fans: 60.63 -> 2.26). All 5
-- show a real, large collapse in relative standing over the window --
-- not just high variance, a consistent one-directional decline.

-- Q5: Describe these customers -- what to show/avoid.
-- These 5 interests (largely entertainment/tech/media-adjacent: Android,
-- TV, movies, general "Techies", entertainment industry professionals)
-- started with strong percentile standing in mid-2018 and collapsed
-- sharply by 2019 -- this reads as a cooling trend rather than steady
-- customers, and marketing spend chasing their earlier high standing
-- would now be targeting a shrinking, less-engaged audience. Recommend
-- treating these as declining segments to monitor rather than growth
-- targets; avoid increasing ad spend on them based on outdated 2018
-- standing, and prioritize interests like Winter Apparel Shoppers or
-- Work Comes First Travelers (C2/C1) that show consistently strong,
-- current performance instead.


-- ================================
-- SECTION D: Index Analysis
-- (avg composition = composition / index_value, rounded to 2 dp)
-- ================================

-- Q1: Top 10 interests by average composition, per month.
WITH ranked AS (
    SELECT month_year, interest_id,
        ROUND(composition / index_value, 2) AS avg_composition,
        RANK() OVER (PARTITION BY month_year ORDER BY composition / index_value DESC) AS rnk
    FROM fresh_segments.interest_metrics
    WHERE month_year IS NOT NULL AND interest_id IS NOT NULL
      AND index_value IS NOT NULL AND index_value != 0
)
SELECT * FROM ranked WHERE rnk <= 10 ORDER BY month_year, rnk;
-- Real result: a genuinely different top-10 list per month (not the same
-- fixed set every time) -- real month-to-month reshuffling, unlike the
-- fake dataset's trivial "all 10 exist" answer.

-- Q2: Of the top 10, which interest appears most often?
WITH ranked AS (
    SELECT month_year, interest_id,
        RANK() OVER (PARTITION BY month_year ORDER BY composition / index_value DESC) AS rnk
    FROM fresh_segments.interest_metrics
    WHERE month_year IS NOT NULL AND interest_id IS NOT NULL
      AND index_value IS NOT NULL AND index_value != 0
)
SELECT r.interest_id, map.interest_name, COUNT(*) AS times_in_top10
FROM ranked r
LEFT JOIN fresh_segments.interest_map map ON r.interest_id::integer = map.id
WHERE r.rnk <= 10
GROUP BY r.interest_id, map.interest_name
ORDER BY times_in_top10 DESC
LIMIT 5;
-- Real result: three-way tie at the top -- Solar Energy Researchers,
-- Alabama Trip Planners, and Luxury Bedding Shoppers each appear in the
-- top 10 in all 14 months. New Years Eve Party Ticket Purchasers and
-- Nursing/Physicians Assistant Journal Researchers follow close behind
-- at 9 months each. A real, non-trivial answer with genuine competition
-- for the top spot, unlike the fake dataset's single dominant "79".

-- Q3: Average of the average composition for the top 10, per month.
WITH ranked AS (
    SELECT month_year, interest_id,
        ROUND(composition / index_value, 2) AS avg_comp,
        RANK() OVER (PARTITION BY month_year ORDER BY composition / index_value DESC) AS rnk
    FROM fresh_segments.interest_metrics
    WHERE month_year IS NOT NULL AND interest_id IS NOT NULL
      AND index_value IS NOT NULL AND index_value != 0
)
SELECT month_year, ROUND(AVG(avg_comp), 2) AS avg_of_avg_composition
FROM ranked WHERE rnk <= 10
GROUP BY month_year ORDER BY month_year;
-- Real result: relatively stable ~5.75-7.07 from Jul 2018 through Apr
-- 2019, then a sharp drop from May 2019 onward (3.54, 2.43, 2.76, 2.63)
-- -- a real regime change partway through the window, not the fake
-- dataset's smooth, uniform decline across the whole period.

-- Q4: 3-month rolling average of max avg composition, Sep 2018-Aug 2019,
--     plus the previous 2 months' top-ranked interest.
WITH monthly_top AS (
    SELECT month_year, interest_id AS top_interest,
        ROUND(composition / index_value, 2) AS max_avg_composition,
        RANK() OVER (PARTITION BY month_year ORDER BY composition / index_value DESC) AS rnk
    FROM fresh_segments.interest_metrics
    WHERE month_year IS NOT NULL AND interest_id IS NOT NULL
      AND index_value IS NOT NULL AND index_value != 0
)
SELECT month_year, top_interest, max_avg_composition,
    LAG(top_interest, 1) OVER (ORDER BY month_year) AS prev_month_top,
    LAG(top_interest, 2) OVER (ORDER BY month_year) AS prev_month_2_top,
    ROUND(AVG(max_avg_composition) OVER (ORDER BY month_year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS rolling_3month_avg
FROM monthly_top
WHERE rnk = 1 AND month_year BETWEEN '2018-09-01' AND '2019-08-01'
ORDER BY month_year;
-- Real result: "Work Comes First Travelers" (21057) holds the #1 spot for
-- six straight months (Sep 2018-Feb 2019), then the top spot changes hands
-- every month or two afterward: Alabama Trip Planners (Mar19), Solar
-- Energy Researchers (Apr19), Readers of Honduran Content (May19), Las
-- Vegas Trip Planners (Jun-Jul19), Cosmetics and Beauty Shoppers (Aug19).
-- rolling_3month_avg falls from 8.26 to 2.77 across the window -- a real,
-- steep decline (not the fake dataset's gentle 2.30->2.16 slide), and it
-- coincides exactly with the D3 regime change starting May 2019.

-- Q5: Why might max average composition change month to month? Could it
--     signal something wrong with the business model?
-- index_value is the normalizing/baseline factor in this ratio -- it can
-- shift independently of any single interest's real popularity, so part
-- of any month-to-month change could be a moving denominator rather than
-- a real change in customer behaviour. But the size and timing of this
-- decline is worth escalating rather than shrugging off as normal index
-- noise: D3 and D4 both show a sharp, sustained drop starting specifically
-- around May 2019 (roughly halving from ~6-7 down to ~2.5-3.5), not a
-- gradual drift. A drop that abrupt and that sustained, landing on
-- basically every interest at once, looks more like either a change in
-- how index_value itself is calculated starting that month, or a genuine,
-- fairly sudden decline in engagement across Fresh Segments' whole
-- audience -- both worth flagging to the business rather than assuming
-- it's just routine variation.


-- ================================
-- APPENDIX: Data quality investigation notes (supporting evidence, not
-- standalone case-study questions)
-- ================================

SELECT COUNT(*) FROM fresh_segments.interest_map;       -- 1,209 real interests
SELECT COUNT(*) FROM fresh_segments.interest_metrics;   -- 14,273 metric rows
SELECT COUNT(DISTINCT interest_id) FROM fresh_segments.interest_metrics WHERE interest_id IS NOT NULL;
SELECT COUNT(DISTINCT month_year) FROM fresh_segments.interest_metrics WHERE month_year IS NOT NULL;
-- 14 real distinct months (Jul 2018-Aug 2019), consistent throughout.

SELECT id, COUNT(*) c FROM fresh_segments.interest_map GROUP BY id HAVING COUNT(*) > 1;
-- 0 rows -- id remains a clean, unique key on the real data too.
