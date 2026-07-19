# Case Study #8: Fresh Segments

## Business Problem

Fresh Segments runs interest-based ad targeting for clients. Two tables cover monthly interest metrics (composition, index value, ranking, percentile ranking) and a reference table mapping interest IDs to human-readable names. The core questions: which interests are reliable enough (consistent history) to target confidently, which are trending up or collapsing, and how does "average composition" (composition normalized by index value) behave over time.

## Dataset

| Table | Description |
|---|---|
| `interest_metrics` | Monthly composition, index value, ranking, and percentile ranking per interest |
| `interest_map` | Reference table mapping interest IDs to human-readable interest names and summaries |

## Key Skills

ALTER COLUMN TYPE USING NULLS FIRST LEFT JOIN Data Quality Verification Uniqueness Checks RANK() ROW_NUMBER() LAG() Rolling Averages Cumulative Percentage Distributions

## What I Solved

**Data Exploration and Cleansing**
- Converted `month_year` from text to a real date type
- Counted records per month, nulls surfaced first
- Quantified and decided how to handle null rows (8.37% of the table)
- Checked `interest_id` mismatches between the two tables
- Verified `interest_map.id` is a clean, unique key
- Verified the correct join type and direction, spot-checked against a known interest ID
- Found and flagged 188 rows dated before their interest's `created_at`

**Interest Analysis**
- Identified interests present in all 14 months (480 of ~1,202)
- Found the cumulative-coverage threshold that passes 90% of interests
- Quantified data points lost under a strict full-coverage cutoff
- Assessed whether that cutoff makes business sense (it doesn't — recommended a softer threshold instead)
- Re-counted unique interests per month under the recommended threshold

**Segment Analysis**
- Top 10 and bottom 10 interests by max composition
- 5 interests with the lowest average ranking
- 5 interests with the largest volatility (stddev) in percentile ranking
- Min/max percentile ranking and the month each occurred, for those 5 volatile interests
- Business read on what those 5 interests represent and how to act on it

**Index Analysis**
- Top 10 interests by average composition, per month
- Which interest appears most often in the monthly top 10
- Trend in the average of the top-10 average composition over time
- 3-month rolling average of the top composition value
- Business interpretation of why average composition shifts month to month

## Approach

An earlier pass at this case study used an AI-generated substitute dataset after hitting what looked like a paywall on the original source. That version produced misleading, artificially clean results (e.g. "every interest has zero nulls" and "every interest appears in all 14 months"), which don't reflect real data behaviour. This version uses the actual dataset (1,209 real interests, 14,273 metric rows), sourced from a public GitHub mirror and independently verified against a published reference solution — matching known values exactly (e.g. `interest_id = 21246`, the case study's own example ID, checks out as "Readers of El Salvadoran Content" with composition ~1.6-2.3 across its available months).

Verified before trusting, every time: `interest_map.interest_name` is not unique by design, so every join and group-by uses `id`, confirmed unique via `GROUP BY id HAVING COUNT(*) > 1` returning zero rows. Used `LEFT JOIN`, not `INNER JOIN`, to combine `interest_metrics` with `interest_map` — this dataset has genuine asymmetry (interests in the reference table with no metrics history, and metrics rows with a null `interest_id`), and an `INNER JOIN` would silently drop real rows. ~8.4% of `interest_metrics` rows have a null `month_year`/`interest_id` — large enough to explicitly exclude (via `WHERE ... IS NOT NULL`) in month/interest-based aggregations rather than ignore.

## Hardest Query

*[Flagged for your confirmation — you didn't specify a hardest query for this one, so this is my best candidate based on complexity, not a fact about your process.]* The cumulative-percentage threshold query (Interest Analysis) — required a CTE computing months-of-coverage per interest, a second CTE collapsing that into a frequency distribution, then a running cumulative percentage to find exactly where the 90% threshold falls, which only became a genuinely meaningful result once the real (lopsided) dataset replaced the artificially uniform AI-generated one.

## Key Takeaway

Verify before trusting a schema or a dataset. Working with a placeholder dataset didn't just fail to catch bugs — it actively produced clean, "correct-looking" answers that were wrong: an artificially uniform dataset masked exactly the kind of real, lopsided distributions (a 480-interest cluster, 60% coverage cutoffs, genuine month-to-month reshuffling) that the real business questions in this case study depend on.

## Key Results

| Question | Finding |
|---|---|
| A3: null rate | 8.37% of metric rows are null (real, non-trivial) |
| A4: ID mismatches | 0 metrics→map, 7 map→metrics (small, real asymmetry) |
| A7: temporal anomaly | 188 rows dated before their interest's `created_at` — flagged for follow-up, not deletion |
| B1: full 14-month coverage | 480 of ~1,202 interests (not all of them) |
| B2: 90% cumulative threshold | `total_months = 14` — genuinely meaningful, driven by a large (480-interest) cluster at full coverage |
| B4: removal threshold recommendation | Argued against the strict `= 14` cutoff (cuts 60% of interests); recommended the softer `>= 6` months threshold the case study itself uses in Section C |
| C1: top/bottom composition | Work Comes First Travelers (21.20) at the top; Astrology Enthusiasts (1.88) at the bottom — genuinely different lists |
| C5: segment read | Entertainment/tech-adjacent interests (Android Fans, TV Junkies, Techies) show a sharp decline in relative standing from 2018→2019 — read as a cooling segment, not a growth target |
| D2: most frequent top-10 interest | 3-way tie: Solar Energy Researchers, Alabama Trip Planners, Luxury Bedding Shoppers (all 14/14 months) |
| D3/D4: composition trend | Stable ~6-7 through April 2019, then a sharp, sustained drop from May 2019 onward — a real regime change worth escalating to the business, not routine index noise |

## What's in This File

- `CS8_Fresh_Segments_Solutions.sql` — all 22 questions (Sections A-D), each with the real query, the real result, and a written insight as inline comments
- `CS8_schema_only.sql` + `interest_map_clean.csv` / `interest_metrics_clean.csv` — importable schema and cleaned data files for anyone who wants to run these queries live (tested via CSV import into a hosted Postgres instance; the raw dataset is large enough — ~14K rows — that pasting it as one giant `INSERT` script hits size limits on some free SQL sandboxes)

## Tools

PostgreSQL 13 · DB Fiddle · GitHub

*Part of Danny Ma's 8 Week SQL Challenge*
