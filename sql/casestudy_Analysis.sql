


-- 1.Lists users with their full name, number of transactions, and total amount spent, ordered by the highest spender.

SELECT u.user_id,CONCAT(u.first_name,'  ' ,u.last_name)AS Full_name,
SUM(t.amount) AS total_spent,COUNT(t.user_id)AS  transaction_count
FROM users1 u
JOIN transactions t ON u.user_id = t.user_id
GROUP BY u.user_id, u.first_name, u.last_name
ORDER BY total_spent DESC;

-- 2.Finds users who have 2 or more open support tickets and calculates the percentage of open tickets.

SELECT u.user_id,
u.first_name, 
u.last_name,
COUNT(*) AS open_tickets,
CONCAT(ROUND(COUNT(*)*100/(SELECT COUNT(*) FROM support_tickets WHERE user_id = u.user_id) ,2),'%')
FROM users1 u
JOIN support_tickets s ON u.user_id = s.user_id
WHERE s.status = 'open'
GROUP BY u.user_id,u.first_name, u.last_name
HAVING open_tickets >=2;

-- 3.Displays each user's loan details including loan amount, total repayment, remaining balance, and repayment ratio.

SELECT 
    l.user_id,
    l.loan_id,
    l.amount AS loan_amount,
    SUM(r.amount) AS repayment,
    l.amount - COALESCE(SUM(r.amount), 0) AS remaining_balance,
    SUM(r.amount) / l.amount AS repayment_ratio
FROM loans l 
JOIN repayments r ON r.loan_id = l.loan_id
GROUP BY l.user_id, l.loan_id, l.amount 
ORDER BY l.user_id;

-- 4.Identifies loans that have been overpaid (i.e., total repayments exceed the original loan amount).

SELECT l.user_id,
  l.loan_id,
  (l.amount) AS loan_amount,
  SUM(r.amount)AS repayment,
  (COALESCE(SUM(r.amount), 0)-l.amount) AS overpaid_amount
FROM loans l 
JOIN repayments r ON r.loan_id=l.loan_id
GROUP BY l.user_id,l.loan_id,l.amount
HAVING  SUM(r.amount)>=l.amount;

-- 5.Calculates how many days it took each user to complete repayments on their loan.

SELECT 
    l.loan_id,u.user_id,u.first_name,
    u.last_name,
    SUM(r.amount) AS total_repayment,
    l.amount AS loan_amount,
   DATEDIFF(MAX(r.repayment_date), l.start_date)AS days_to_repay
    FROM users1 u 
    JOIN loans l ON  u.user_id=l.user_id
    JOIN repayments r  ON r.loan_id= l.loan_id
    GROUP BY  l.loan_id,u.user_id,u.first_name,u.last_name, l.start_date,l.amount
    ORDER BY u.user_id  ;

-- 6.Shows the number of transactions per month for the past 12 months.

SELECT 
     DATE_FORMAT(transaction_date, '%Y-%m') AS month, 
     COUNT(*) AS total_transactions
FROM transactions
WHERE transaction_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY month
ORDER BY month;

-- 7.Analyzes support ticket activity: total users, users with/without tickets, and submission rate.

SELECT
  COUNT(DISTINCT u.user_id) AS total_users,
  COUNT(DISTINCT s.user_id) AS users_with_tickets,
  COUNT(DISTINCT u.user_id) - COUNT(DISTINCT s.user_id) AS users_without_tickets,
  CONCAT(
    ROUND(COUNT(DISTINCT s.user_id) * 100.0 / COUNT(u.user_id), 2),
    '%'
  ) AS ticket_submission_rate
FROM users1 u
LEFT JOIN support_tickets s ON u.user_id = s.user_id;

-- 8.Retrieves loans that have reached or passed their end date based on their term duration.

SELECT 
   u.first_name,
   u.last_name,
   l.user_id,
   l.loan_id,
   l.start_date,
   DATE_ADD(l.start_date,INTERVAL l.term_months MONTH ) AS end_date,
   DATEDIFF(DATE_ADD(l.start_date,INTERVAL l.term_months MONTH ),CURDATE())  AS days_past_due
FROM loans l
LEFT JOIN repayments r ON r.loan_id=l.loan_id
JOIN  users1 u ON l.user_id=u.user_id
WHERE  DATE_ADD(l.start_date,INTERVAL l.term_months MONTH ) <= CURDATE();

-- 9.Classifies each loan's status based on repayments and due date (CTE version)

-- 📊 Loan Summary Report per User
-- Includes repayment ratio, status, and timing
-- ========================================

WITH loans_cte AS (
    SELECT 
        l.user_id,
        l.loan_id,
        l.term_months,
        l.amount AS loan_amount,
        l.start_date,
        -- Calculate loan end date by adding term in months
        CAST(DATEADD(MONTH, l.term_months, l.start_date) AS DATE) AS end_date
    FROM loans l
)

SELECT 
    -- 👤 Full name of the user
    u.first_name + ' ' + u.last_name AS full_name,
    
    -- 🔢 Loan details
    lc.loan_id,
    lc.start_date,
    lc.end_date,
    COALESCE(lc.loan_amount, 0) AS loan_amount,

    -- 💰 Total amount repaid toward this loan
    ROUND(COALESCE(SUM(r.amount), 0), 2) AS total_repaid,

    -- 📈 Repayment ratio (total repaid / loan amount)
    CAST(COALESCE(SUM(r.amount), 0) AS FLOAT) / NULLIF(COALESCE(lc.loan_amount, 0), 0) AS repayment_ratio,

    -- 💸 Difference between what was repaid and the original loan
    COALESCE(SUM(r.amount), 0) - COALESCE(lc.loan_amount, 0) AS repayment_difference,

    -- ⏳ Days until loan is due (negative = overdue)
    DATEDIFF(DAY, GETDATE(), lc.end_date) AS days_to_due,

    -- 📌 Loan status
    CASE 
        WHEN COALESCE(SUM(r.amount), 0) >= COALESCE(lc.loan_amount, 0) THEN 'Repaid'
        WHEN lc.end_date < CAST(GETDATE() AS DATE) THEN 'Overdue'
        ELSE 'Active'
    END AS loan_status

FROM users u
JOIN loans_cte lc ON u.user_id = lc.user_id
LEFT JOIN repayments r ON r.loan_id = lc.loan_id

-- Grouping ensures we aggregate repayments per loan
GROUP BY 
    u.first_name, u.last_name,
    lc.loan_id,
    lc.loan_amount,
    lc.start_date,
    lc.end_date;
-- 10.Find users who made 2 or more transactions on the same day.

WITH  daily_transaction_counts AS (
  SELECT 
  user_id,
  DATE_FORMAT(transaction_date,'%Y-%m-%d') AS txn_Date ,
  COUNT(*) AS txn_count
FROM transactions
GROUP BY user_id,txn_Date
)
SELECT 
  user_id,
  txn_date,
  txn_count
  FROM daily_transaction_counts 
  WHERE txn_count>=2;

-- 11. Ranks users based on the number of support tickets submitted, using DENSE_RANK() to avoid rank gaps in case of ties.

SELECT 
    u.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS full_name,
    COUNT(s.ticket_id) AS total_tickets,
    DENSE_RANK () OVER (ORDER BY COUNT(s.ticket_id) DESC) AS ticket_rank
FROM users1 u
JOIN support_tickets s ON u.user_id = s.user_id
GROUP BY u.user_id, u.first_name, u.last_name;

-- 12.Calculates the average repayment amount grouped by the loan term in months.

WITH term_repayments AS (
  SELECT 
    l.term_months,
    r.amount
  FROM loans l
  JOIN repayments r ON l.loan_id = r.loan_id
)
SELECT 
  term_months,
  AVG(amount) AS avg_repay
FROM term_repayments
GROUP BY term_months
ORDER BY term_months;

-- 13.Shows each repayment alongside the average repayment for loans with 
-- the same term duration using a window function.

SELECT 
  l.loan_id,
  l.term_months,
  r.repayment_id,
  r.amount AS repayment_amount,
  AVG(r.amount) OVER (PARTITION BY l.term_months) AS avg_repay_for_term
FROM loans l
JOIN repayments r ON l.loan_id = r.loan_id
ORDER BY l.term_months, l.loan_id;

-- 14. DATEDIFF. This helps analyze user activation delay.

WITH first_transactions AS (
  SELECT 
    u.user_id,
    u.registration_date,
    MIN(t.transaction_date) AS first_transaction_date
  FROM users1 u
  LEFT JOIN transactions t ON u.user_id = t.user_id
  GROUP BY u.user_id, u.registration_date
)
SELECT 
  user_id,
  registration_date,
  DATE(first_transaction_date) AS first_transaction_date,
  DATEDIFF(DATE(first_transaction_date), registration_date) AS days_until_first_tx
FROM first_transactions;

-- 15.-- Useful for understanding seasonal trends in loan issuance.

WITH Seasonal_loans AS (
SELECT 
CONCAT(YEAR (start_date),'-Q' ,quarter(start_date)) AS Quarter
FROM loans)
SELECT  Quarter,COUNT(*) AS total_loans
FROM Seasonal_loans
GROUP BY Quarter
ORDER BY quarter;

-- 16.Identify closed loans (those past their end date) and classify them based on repayment status:
--     Overpayment, Underpayment, or Fully Paid.

--  Step 1: Prepare a summary of loans with their total repayments and calculated end dates
WITH loan_summary AS (
  SELECT 
    l.user_id,
    l.loan_id,
    l.amount AS loan_amount,
    l.start_date,
    DATE_ADD(l.start_date, INTERVAL l.term_months MONTH) AS end_date,
    COALESCE(SUM(r.amount), 0) AS total_repayment
  FROM loans l
  JOIN repayments r ON l.loan_id = r.loan_id
  GROUP BY l.loan_id, l.amount, l.user_id, l.term_months, l.start_date
)

-- Step 2: Determine repayment status and filter only loans that have passed their end date
SELECT 
  loan_id,
  loan_amount,
  total_repayment,
  user_id,
  start_date,
  end_date,
  (loan_amount - total_repayment) AS Amount_difference,
  CASE 
    WHEN total_repayment  > loan_amount THEN 'Overpayment'
    WHEN  total_repayment < loan_amount THEN 'Underpayment'
    ELSE 'Fully_paid'
  END AS status
FROM loan_summary
WHERE end_date <= CURDATE();  -- Only show loans that have matured

-- 17.-- Step 1: Count transactions per user per month.

WITH monthly_transactions AS (
    SELECT 
        user_id,
        DATE_FORMAT(transaction_date, '%Y-%m') AS `month`,
        COUNT(*) AS transaction_count
    FROM transactions
    GROUP BY user_id, `month`
),

-- Step 2: Filter for exactly 2 months ago
filtered_transactions AS (
    SELECT *
    FROM monthly_transactions
    WHERE `month` = DATE_FORMAT(CURDATE() - INTERVAL 2 MONTH, '%Y-%m')
)

-- Step 3: Rank users based on transaction volume in that month
SELECT 
    user_id,
    transaction_count,
    `month`,
    RANK() OVER (ORDER BY transaction_count DESC) AS rank_users
FROM filtered_transactions;

-- 18.-- Cohort analysis: tracks monthly user retention by identifying each user's first transaction (cohort date),
-- and counting how many unique users are active in subsequent months relative to their cohort.

WITH cohort_cte AS (
    SELECT 
        user_id,
        MIN(transaction_date) AS cohort_date
    FROM transactions
    GROUP BY user_id
)

SELECT 
    DATE_FORMAT(c.cohort_date, '%Y-%m') AS cohort_month,
    DATE_FORMAT(t.transaction_date, '%Y-%m') AS activity_month,
    TIMESTAMPDIFF(MONTH, c.cohort_date, t.transaction_date) AS month_offset,
    COUNT(DISTINCT t.user_id) AS active_users
FROM cohort_cte c
JOIN transactions t ON c.user_id = t.user_id
GROUP BY 
    DATE_FORMAT(c.cohort_date, '%Y-%m'),
    DATE_FORMAT(t.transaction_date, '%Y-%m'),
    TIMESTAMPDIFF(MONTH, c.cohort_date, t.transaction_date)
ORDER BY cohort_month, month_offset;

-- 19.Select users whose account balance is more than twice the average balance of all users.
-- Uses a CTE to avoid recalculating the average and keeps the logic clean and efficient.

WITH avg_cte AS (
    SELECT AVG(account_balance) AS avg_balance_all
    FROM users1
)

SELECT u.*
FROM users1 u
JOIN avg_cte a
WHERE u.account_balance > 2 * a.avg_balance_all;

-- 20. Analyze the loan repayment patterns using LAG to calculate the interval between payments.

WITH lag_cte AS (
  SELECT 
    r.repayment_id,
    r.loan_id,
    r.amount,
    r.repayment_date,
    LAG(r.repayment_date) OVER (PARTITION BY r.loan_id ORDER BY r.repayment_date) AS previous_payment,
    DATEDIFF(r.repayment_date, LAG(r.repayment_date) OVER (PARTITION BY r.loan_id ORDER BY r.repayment_date)) AS days_between
  FROM repayments r
)

SELECT 
  c.repayment_id,
  c.loan_id,
  l.user_id,
  c.amount,
  c.repayment_date,
  c.previous_payment,
  c.days_between
FROM lag_cte c
JOIN loans l ON l.loan_id = c.loan_id;

-- 21.This query identifies rapid successive loan repayments by users, 
-- where the time between two repayments is less than 2 minutes.
-- It uses a CTE to calculate the previous repayment timestamp per user
-- using the LAG window function, and then filters based on the time gap.

WITH txn_with_lag AS (
  SELECT 
    l.user_id, t.transaction_id, r.repayment_date,
    LAG(r.repayment_date) OVER (PARTITION BY l.user_id ORDER BY r.repayment_date) AS prev_time
  FROM repayments r
  JOIN loans l ON l.loan_id = r.loan_id
  JOIN transactions t ON t.user_id = l.user_id
)
SELECT *
FROM txn_with_lag
WHERE TIMESTAMPDIFF(SECOND, prev_time, repayment_date) < 120; 

-- 22.This query evaluates the repayment status of each loan.
-- It joins loans with repayments, calculates total repayments,
-- estimates the loan end date, and classifies repayment status
-- as 'Repaid', 'Partially Paid', or 'Unpaid' using a CASE statement.

WITH display_repayment AS (
SELECT l.user_id,l.loan_id,l.amount AS loan_amount,l.start_date,l.term_months,
DATE_ADD(l.start_date,INTERVAL l.term_months MONTH )AS End_date,
COALESCE(SUM(r.amount))AS total_repayments
FROM loans l
LEFT JOIN repayments r ON l.loan_id=r.loan_id
GROUP BY  l.user_id,l.loan_id, loan_amount,l.start_date, l.term_months
)
SELECT 
user_id,loan_id, loan_amount,start_date,term_months,End_date,total_repayments,
CASE 
	WHEN total_repayments = 0 THEN 'Unpaid'
    WHEN total_repayments >= loan_amount THEN 'Repaid'
    ELSE 'Partially Paid'
END AS repayment_status
FROM display_repayment;

WITH display_repayment AS (
  SELECT 
    l.user_id,
    l.loan_id,
    l.amount AS loan_amount,
    l.start_date,
    l.term_months,
    DATE_ADD(l.start_date, INTERVAL l.term_months MONTH) AS end_date,
    COALESCE(SUM(r.amount), 0) AS total_repayments
  FROM loans l
  LEFT JOIN repayments r ON l.loan_id = r.loan_id
  GROUP BY 
    l.user_id, l.loan_id, loan_amount, l.start_date, l.term_months
)

SELECT 
  user_id,
  loan_id,
  loan_amount,
  start_date,
  term_months,
  end_date,
  total_repayments,
  CASE 
    WHEN total_repayments = 0 AND end_date < CURDATE() THEN 'Overdue'
    WHEN total_repayments = 0 THEN 'Unpaid'
    WHEN total_repayments < loan_amount AND end_date < CURDATE() THEN 'Overdue'
    WHEN total_repayments >= loan_amount THEN 'Repaid'
    ELSE 'Partially Paid'
  END AS repayment_status
FROM display_repayment;

-- 23.This query selects all users who have both a transaction and a repayment
-- within the past 3 months. It uses a CTE for clarity, and filters using full date comparison.

WITH users_active AS (
  SELECT
    t.user_id,
    t.transaction_date,
    r.repayment_date
  FROM transactions t
  JOIN loans l ON l.user_id = t.user_id
  JOIN repayments r ON l.loan_id = r.loan_id
)
SELECT user_id,
DATE_FORMAT(transaction_date, '%Y-%m-%d'),
DATE_FORMAT(repayment_date, '%Y-%m-%d')
FROM users_active
WHERE transaction_date >= CURDATE() - INTERVAL 3 MONTH
  AND repayment_date >= CURDATE() - INTERVAL 3 MONTH;

-- 24.This query calculates each user's repayment performance per loan.
-- It identifies whether a loan is overpaid, underpaid (negative balance), or fully paid.

WITH repayment_summary AS (
SELECT 
   u.user_id,
   u.first_name,
   u.last_name,
   l.loan_id,
   l.amount AS Loan_amount,
COALESCE(SUM(r.amount),0)AS Total_repayments,
( COALESCE(SUM(r.amount),0)- l.amount )AS Loan_balance
FROM users1 u
JOIN loans l ON u.user_id=l.user_id
JOIN repayments r ON l.loan_id=r.loan_id
GROUP BY u.user_id,u.first_name,u.last_name,l.loan_id,l.amount
)
SELECT
   user_id,
   first_name,
   last_name,
   loan_id,
   Loan_amount,
   Total_repayments,
   Loan_balance,
CASE 
	WHEN Loan_balance>0 THEN 'Overpaid'
	WHEN Loan_balance<0 THEN 'Negative'
	ELSE'Fully Paid'
END
AS repayment_status
FROM repayment_summary;


-- 25.This query calculates the overall loan repayment ratio for each user.
-- It divides the total repayments (SUM of r.amount) by the total loan amounts (SUM of l.amount),
-- grouped by user_id. This helps identify users who have repaid their loans fully, partially, or excessively.

SELECT 
  l.user_id,
  SUM(r.amount) /SUM(l.amount) AS repayment_ratio
FROM loans l
JOIN repayments r ON l.loan_id = r.loan_id
GROUP BY l.user_id
ORDER BY repayment_ratio DESC;

-- 26.
 --    CTE 1: Find users who have taken at least 2 loans
WITH users_with_2_loans AS (
  SELECT 
    user_id, 
    COUNT(*) AS loan_count
  FROM loans 
  GROUP BY user_id
  HAVING loan_count >= 2
),

-- CTE 2: Get summary of loans that are fully repaid (or overpaid)
loan_summary AS (
  SELECT 
    l.user_id,
    l.loan_id,
    l.amount AS loan_amount,
    COALESCE(SUM(r.amount), 0) AS total_repayment
  FROM loans l 
  JOIN repayments r ON l.loan_id = r.loan_id
  GROUP BY l.user_id, l.loan_id, l.amount
  HAVING total_repayment >= l.amount
)

-- Final query: Display fully repaid loans for users with at least 2 loans
SELECT 
  u.user_id, 
  u.first_name,
  u.last_name,
  l.loan_id,
  l.start_date,
  DATE_ADD(l.start_date, INTERVAL l.term_months MONTH) AS end_date,
  l.amount AS loan_amount,
  ROUND(COALESCE(SUM(r.amount), 0), 2) AS total_repayments,
  ROUND(COALESCE(SUM(r.amount), 0) - l.amount, 2) AS loan_balance,
  
  -- Categorize repayment status
  CASE 
    WHEN COALESCE(SUM(r.amount), 0) > l.amount THEN 'Overpaid'
    WHEN COALESCE(SUM(r.amount), 0) = l.amount THEN 'Fully Paid'
    ELSE 'Error'
  END AS repayment_status

FROM users1 u
JOIN loans l ON u.user_id = l.user_id
JOIN repayments r ON l.loan_id = r.loan_id
JOIN users_with_2_loans uw ON uw.user_id = l.user_id
JOIN loan_summary ls ON l.loan_id = ls.loan_id

GROUP BY 
  u.user_id, u.first_name, u.last_name, 
  l.loan_id, l.amount, l.term_months, l.start_date

ORDER BY u.user_id, l.loan_id;

-- 27.
-- Step 1: Calculate average transaction per user
WITH avg_transactions AS (
  SELECT 
    user_id, 
    ROUND(AVG(amount), 2) AS avg_transaction
  FROM transactions
  GROUP BY user_id
)

-- Step 2: Rank users by their average transaction amount

SELECT 
  user_id,
  avg_transaction,
  DENSE_RANK() OVER (ORDER BY avg_transaction DESC) AS user_rank
FROM avg_transactions;


-- 28.users with a significant difference between their debit and credit transactions.

SELECT 
  user_id,
  SUM(CASE WHEN transaction_type = 'credit' THEN amount ELSE 0 END) AS total_credit,
  SUM(CASE WHEN transaction_type = 'debit' THEN amount ELSE 0 END) AS total_debit,
  ABS(
      SUM(CASE WHEN transaction_type = 'credit' THEN amount ELSE 0 END) - 
      SUM(CASE WHEN transaction_type = 'debit' THEN amount ELSE 0 END)
      ) AS difference
FROM transactions
GROUP BY user_id
ORDER BY difference DESC;

-- 29. Summarize number and total amount of transactions per user and type, with subtotals and total using ROLLUP

SELECT 
  user_id,
  transaction_type,
  COUNT(*) AS txn_count,
  SUM(amount) AS total_amount,
  CASE
    WHEN user_id IS NULL THEN 'Total'
    WHEN transaction_type IS NULL THEN 'User subtotal'
    ELSE 'Detailed'
  END AS group_level
FROM transactions
GROUP BY user_id, transaction_type WITH ROLLUP;

-- 30. Analyze total loans and repayment rate grouped by loan term duration
SELECT 
  l.term_months,
  COUNT(DISTINCT l.loan_id) AS total_loans,
  SUM(r.amount) AS total_repayment,
  SUM(r.amount) / SUM(l.amount) AS overall_repayment_rate
FROM loans l
LEFT JOIN repayments r ON l.loan_id=r.loan_id
GROUP BY l.term_months 
ORDER BY l.term_months;

-- 31. This query identifies users whose first transaction occurred within 7 days of their registration date.
-- It uses a common table expression (CTE) with ROW_NUMBER to ensure only the earliest transaction per user is evaluated.
-- Useful for analyzing user onboarding engagement or early activation behavior.

WITH First_transactions AS (
SELECT 
u.user_id,
u.last_name,
u.first_name,
u.registration_date,
t.transaction_date,
DATEDIFF(t.transaction_date,u.registration_date )AS difference,
ROW_NUMBER () OVER (PARTITION BY u.user_id ORDER BY t.transaction_date )AS row_num
FROM users1 u
JOIN transactions t ON u.user_id=t.user_id
)
SELECT * FROM  First_transactions
WHERE  row_num=1 AND difference<=7;

 -- 32.Calculate the average time gap between transactions for each user.

WITH time_gap AS (
SELECT 
 user_id,transaction_date,
LAG (transaction_date) OVER ( PARTITION BY user_id ORDER BY transaction_date  ) AS prev_txn
 FROM transactions
 )
 SELECT 
user_id,
avg(timestampdiff(hour,prev_txn,transaction_date))avg_time_gap
FROM  time_gap
GROUP BY user_id
HAVING avg_time_gap IS NOT NULL ;

-- 33. Calculate the ratio of users who have loans to the total number of users.

SELECT 
ROUND(
  (SELECT COUNT(DISTINCT user_id) FROM loans) / COUNT(*),4) AS loan_ratio
FROM users;

-- 34. Calculate the ratio of users who have taken loans to the total number of users.
-- Helps identify the loan participation rate among the user base.

SELECT 
  COUNT(DISTINCT l.user_id) AS users_with_loans,
  COUNT(DISTINCT u.user_id) AS total_users,
  COUNT(DISTINCT l.user_id) / COUNT(DISTINCT u.user_id) AS ratio
FROM users1 u
LEFT JOIN loans l ON l.user_id = u.user_id;

--  35.Analyze each user's share of the total number of loans in the system.
-- This query calculates the number of loans per user and compares it to the total number of loans,
-- helping identify which users account for a larger portion of issued loans.

WITH user_loan_counts AS (
SELECT l.user_id,COUNT(*)AS loan_count
FROM loans l
GROUP BY l.user_id
),
total_loan_count AS (
SELECT 
COUNT(l.loan_id)AS Total_loans
FROM loans l 
)
SELECT 
  u.user_id,
  t.Total_loans,loan_count,
 ROUND(u.loan_count / t.total_loans, 4) AS loan_ratio
  FROM user_loan_counts u 
  CROSS JOIN total_loan_count t 
ORDER BY loan_count DESC ;

--36.Which users have submitted the highest number of support tickets?

WITH TicketCounts AS (
    SELECT 
        user_id,
        COUNT(*) AS ticket_count
    FROM Support_Tickets
    GROUP BY user_id
),
RankedUsers AS (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY ticket_count DESC) AS ticket_rank
    FROM TicketCounts
)
SELECT ru.*, u.first_name, u.last_name
FROM RankedUsers ru
JOIN Users u ON u.user_id = ru.user_id
WHERE ru.ticket_rank <= 5;

--37.Which users have made transactions, and what was the amount of their most recent transaction?
--Also,what is their current account balance?

CREATE VIEW vw_userlasttransaction AS 
WITH rank_transactions AS (
SELECT t.user_id,t.amount,t.transaction_date AS last_transaction_date
,
ROW_NUMBER() OVER (PARTITION BY t.user_id ORDER BY t.transaction_date DESC)AS ROW_num
FROM transactions t)
SELECT rn.user_id,concat(u.first_name,' ',u.last_name)AS Full_Name,rn.amount AS last_transaction_amount,
rn.transaction_date,u.account_balance,rn.ROW_num
FROM users u 
LEFT JOIN rank_transactions rn ON rn.user_id=u.user_id
WHERE ROW_num=1;
