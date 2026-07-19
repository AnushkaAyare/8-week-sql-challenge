# Case Study #4: Data Bank

## Business Problem

Data Bank is a digital-only neo-bank that links customer cloud storage allocation directly to account balances. The team needs to understand node distribution, analyse transaction behaviour, and forecast data storage requirements under multiple allocation models including a daily interest-based growth model.

## Dataset

| Table | Description |
|---|---|
| `regions` | 5 global regions where nodes operate |
| `customer_nodes` | Customer-to-node assignments with start and end dates |
| `customer_transactions` | All deposit, purchase, and withdrawal transactions |

## Key Skills

GENERATE_SERIES LAG FIRST_VALUE LAST_VALUE PERCENTILE_CONT RANGE BETWEEN INTERVAL GREATEST POWER Running Balances Date Spine Generation

## What I Solved

**Customer Nodes Exploration**
- Unique node count and distribution per region
- Customer allocation per region
- Average node reallocation period
- Percentile analysis of reallocation days per region (median, 80th, 95th)

**Customer Transactions**
- Transaction counts and totals by type
- Average deposit frequency and amount per customer
- Monthly customer segmentation by transaction behaviour
- Cumulative closing balance per customer per month
- Percentage of customers growing closing balance by 5%+

**Data Allocation Challenge**

Three allocation strategies modelled and compared:

| Option | Logic | Technique |
|---|---|---|
| Option 1 | Previous month-end balance | `LAG()` |
| Option 2 | Average balance over previous 30 days | `RANGE BETWEEN INTERVAL '30 days'` |
| Option 3 | Real-time running balance | `SUM() OVER()` per transaction |

**Interest-Based Allocation**
- Simple daily interest: `balance × (0.06 / 365)` per day
- Compound daily interest: `balance × POWER(1 + 0.06/365, days_elapsed)`

## Approach

Built running balances using `SUM() OVER()` partitioned by customer. Used `DATE_TRUNC` for monthly snapshots and `LAG()` for previous month lookups. Generated a full daily date spine per customer using `GENERATE_SERIES`, then `LEFT JOIN`ed transactions onto it so every day has a balance — even days with no activity. Applied `GREATEST(value, 0)` throughout to floor negative balances before allocation. Chained up to five CTEs for the interest calculations.

## Hardest Query

The interest-based allocation section — generating a daily date spine per customer with `GENERATE_SERIES`, carrying forward the running balance through days with no transactions using `LEFT JOIN` and `COALESCE`, then applying daily interest on top of that.

## Key Takeaway

When your data has gaps in time, generate the spine first and join data onto it — never the other way around. `GENERATE_SERIES` combined with `LEFT JOIN` is the standard pattern for any daily balance, inventory, or time-series problem.

## Tools

PostgreSQL 13 · DB Fiddle · GitHub

*Part of Danny Ma's 8 Week SQL Challenge*
