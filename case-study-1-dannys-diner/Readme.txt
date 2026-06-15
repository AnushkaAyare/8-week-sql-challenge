Case Study 1: Danny's Diner

Key Skills: Joins, CTEs, Window Functions

The Business Problem

Danny's Diner serves sushi, curry, and ramen, and wants to understand customer spending, visit frequency, and favourite items to decide whether to expand his loyalty program — including points calculations and two bonus tables combining sales, menu, and membership data.

Approach


Joined sales, menu, and members to combine order, pricing, and membership info
Used DENSE_RANK() to find first/most popular items per customer, and items purchased before/after joining
Used CASE + CTEs to calculate points, including the sushi multiplier and first-week 2x bonus
Built the bonus tables with a CTE tagging membership status (Y/N), then DENSE_RANK() partitioned by customer and status — non-members left unranked (NULL)


Key Takeaway

First real introduction to window functions, especially DENSE_RANK() for ranking within groups, and basic CTEs for breaking a problem into steps (tag it, then rank/aggregate). This "clean, tag, then rank" pattern carried into the more complex CTE work later.
