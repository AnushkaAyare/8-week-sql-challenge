# Case Study #1: Danny's Diner

## Business Problem
Danny's Diner serves sushi, curry, and ramen and wants to understand customer spending patterns, visit frequency, and favourite menu items to decide whether to expand his loyalty program. The analysis covers points calculations and bonus membership tables combining sales, menu, and membership data.

---

## Dataset
| Table | Description |
|---|---|
| `sales` | Customer purchases with dates and product IDs |
| `menu` | Product names and prices |
| `members` | Customer membership join dates |

---

## Key Skills
`JOIN` `CTE` `DENSE_RANK()` `CASE WHEN` `Window Functions`

---

## What I Solved

### Customer Behaviour
- Total spend per customer
- Visit frequency per customer
- First item purchased per customer

### Loyalty Program Analysis
- Most popular menu item overall and per customer
- Items purchased before and after joining membership
- Points calculation with sushi 2x multiplier and first-week bonus

### Bonus Tables
- Tagged membership status (Y/N) per order
- Ranked orders per customer by membership status

---

## Approach
Joined sales, menu, and members tables to combine order, pricing, and membership data into a single working dataset. Used DENSE_RANK() partitioned by customer to find first purchases and most popular items. Built points logic using CASE WHEN to handle the sushi multiplier and first-week 2x bonus. For bonus tables, used a CTE to tag membership status first, then applied DENSE_RANK() partitioned by customer and status — leaving non-members unranked with NULL.

---

## Hardest Query
The bonus ranking table — tagging membership status first in a CTE, then ranking within each status group, required thinking about the problem in two separate layers before writing any aggregation.

---

## Key Takeaway
Window functions need a defined partition and order before they make sense. The "clean, tag, then rank" CTE pattern — established here — carried through every more complex case study that followed.

---

## Tools
PostgreSQL 13 · DB Fiddle · GitHub

---

*Part of [Danny Ma's 8 Week SQL Challenge](https://8weeksqlchallenge.com/)*
