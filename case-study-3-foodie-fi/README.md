# Case Study #3 — Foodie-Fi

## Business Context
Foodie-Fi is a subscription streaming service for food content.
Danny needs help understanding customer behaviour across plans —
who converts after trial, who churns, and how long it takes 
customers to commit to annual subscriptions.

## What I Solved

**Churn Analysis**
- Overall churn rate across all customers
- Customers who churned immediately after trial (trial → churn, no paid plan)
- Downgrade patterns from pro monthly to basic monthly

**Conversion Analysis**
- Post-trial plan distribution — where do customers go after free trial?
- Average days from trial start to annual plan upgrade
- 30-day bucket breakdown of upgrade timing

**Point-in-Time Snapshot**
- Active plan distribution at 2020-12-31 using DENSE_RANK 
  to capture each customer's most recent plan at that exact date

**Payments Table**
- Generated full 2020 payments using a recursive CTE — 
  monthly billing cycles, mid-period upgrades, 
  and prorated charges when switching plans

## Hardest Query
First time using WITH RECURSIVE in a real business context. 
Generating monthly payment rows per customer while handling 
plan upgrades mid-cycle and stopping at year end 
required thinking about recursion as a billing engine, 
not just a loop.

## Key Concepts
`LEAD`, `DATE_TRUNC`, `DENSE_RANK`, `WITH RECURSIVE`,
subqueries for percentage calculations against total customer base.

---
*PostgreSQL · DB Fiddle*
