USE casestudy2;

DESCRIBE transactions;
DESCRIBE support_tickets;


SELECT 
    COUNT(*) AS total_rows,
    COUNT(user_id) AS user_id_not_null,
    COUNT(amount) AS amount_not_null
FROM transactions;


SELECT * FROM transactions WHERE amount <= 0;

SELECT DISTINCT transaction_type FROM transactions;

SELECT DISTINCT status FROM support_tickets;

SELECT * FROM support_tickets 
WHERE issue IS NULL OR issue = '' ;

SELECT  user_id,COUNT(*) AS duplicate_count
FROM support_tickets
GROUP BY user_id
HAVING COUNT(*) > 1;


SELECT *
FROM transactions t
LEFT JOIN users1  u ON t.user_id = u.user_id
WHERE u.user_id IS NULL;


SELECT transaction_id, COUNT(*) 
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;

SELECT ticket_id, COUNT(*)
FROM support_tickets
GROUP BY ticket_id
HAVING COUNT(*) > 1;

SELECT * 
FROM transactions 
WHERE transaction_date > NOW();


DESCRIBE loans;

SELECT 
    COUNT(*) AS total_loans,
    COUNT(user_id) AS user_id_not_null,
    COUNT(amount) AS loan_amount_not_null
FROM loans;

SELECT loan_id, COUNT(*) AS duplicate_count
FROM loans
GROUP BY loan_id
HAVING COUNT(*) > 1;

SELECT * 
FROM loans l
LEFT JOIN users u ON l.user_id = u.user_id
WHERE  u.user_id IS NULL;


SELECT * 
FROM loans
WHERE amount <= 0;
SELECT *FROM users1;