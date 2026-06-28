# Case Study #3: Foodie-Fi

## Business Problem
Foodie-Fi is a subscription streaming service for food content. Danny needs to understand customer behaviour across subscription plans — who converts after trial, who churns, how long it takes customers to commit to annual plans, and what the full payment history looks like across 2020.

---

## Dataset
| Table | Description |
|---|---|
| `plans` | Subscription plan names and prices |
| `subscriptions` | Customer plan history with start dates |

---

## Key Skills
`LEAD` `DATE_TRUNC` `DENSE_RANK` `WITH RECURSIVE` `Churn Analysis` `Subscription Pattern Analysis`

---

## What I Solved

### Churn Analysis
- Overall churn rate across all customers
- Customers who churned immediately after trial
- Downgrade patterns from pro monthly to basic monthly

### Conversion Analysis
- Post-trial plan distribution
- Average days from trial to annual plan upgrade
- 30-day bucket breakdown of upgrade timing

### Point-in-Time Snapshot
- Active plan distribution at 2020-12-31 using DENSE_RANK to capture each customer's most recent plan

### Payments Table
- Generated full 2020 payment history using a recursive CTE handling monthly billing cycles, mid-period upgrades, and prorated charges

---

## Approach
Used LEAD() to look ahead at each customer's next plan and identify churn and downgrade events. Used DENSE_RANK() partitioned by customer to find the most recent plan at a specific date. Built the payments table with WITH RECURSIVE — treating it as a billing engine that generates one payment row per month per customer, stopping at year end or plan cancellation, with prorated amounts on mid-cycle upgrades.

---

## Hardest Query
The recursive payments table — required thinking about recursion as a billing cycle generator, not just a loop. Each recursive step produces one month's payment and passes the updated date forward until the termination condition is met.

---

## Key Takeaway
WITH RECURSIVE is the right tool when you need to generate rows based on previous rows — billing cycles, date series, hierarchical data. Once the anchor and recursive member are clearly defined, the rest follows logically.

---

## Tools
PostgreSQL 13 · DB Fiddle · GitHub

---

*Part of [Danny Ma's 8 Week SQL Challenge](https://8weeksqlchallenge.com/)*
