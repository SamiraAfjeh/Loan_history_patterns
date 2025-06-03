USE casestudy2;

SELECT 
SUM(CASE WHEN user_id IS NULL then 1 ELSE 0 end)AS missing_user_id,
SUM(CASE WHEN first_name IS NULL then 1 ELSE 0 end)AS missing_first_name,
SUM(CASE WHEN last_name IS NULL then 1 ELSE 0 end)AS missing_last_name,
SUM(CASE WHEN email IS NULL then 1 ELSE 0 end)AS missing_email,
SUM(CASE WHEN phone IS NULL then 1 ELSE 0 end)AS missing_phone,
SUM(CASE WHEN date_of_birth IS NULL then 1 ELSE 0 end)AS missing_date_of_birth,
SUM(CASE WHEN address IS NULL then 1 ELSE 0 end)AS missing_address,
SUM(CASE WHEN registration_date IS NULL then 1 ELSE 0 end)AS missing_registration_date,
SUM(CASE WHEN account_balance IS NULL then 1 ELSE 0 end)AS missing_account_balance
FROM users1;

WITH duplicated_cte AS (
SELECT*,
ROW_NUMBER () OVER (PARTITION BY first_name,last_name,email ORDER BY user_id)AS row_num
FROM users1)
SELECT* FROM duplicated_cte 
WHERE row_num >1;

SELECT *FROM users1
WHERE first_name='angela' AND last_name='Smith';


SELECT email 
FROM users1
WHERE email NOT REGEXP '^[A-Za-z0-9.-_%+]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}$';

SELECT phone FROM users1;

ALTER TABLE users1 ADD COLUMN Extension varchar(20);


CREATE FUNCTION dbo.fn_CleanPhoneNumber1 (
    @input NVARCHAR(50)
)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @cleaned NVARCHAR(50);

    SET @cleaned = @input;
    
    SET @cleaned = REPLACE(@cleaned, '+', '');
    SET @cleaned = REPLACE(@cleaned, '-', '');
    SET @cleaned = REPLACE(@cleaned, '.', '');
    SET @cleaned = REPLACE(@cleaned, '(', '');
    SET @cleaned = REPLACE(@cleaned, ')', '');
    SET @cleaned = REPLACE(@cleaned, ' ', '');

    
    
    IF LEFT(@cleaned, 3) = '001'
        SET @cleaned = SUBSTRING(@cleaned, 4, LEN(@cleaned));
    ELSE IF LEFT(@cleaned, 1) = '1' AND LEN(@cleaned) = 11
        SET @cleaned = SUBSTRING(@cleaned, 2, LEN(@cleaned));

    RETURN @cleaned;
END;

SELECT 
  phone,
  dbo.fn_CleanPhoneNumber1(phone) AS cleaned_phone
FROM users1;

UPDATE users1 
SET phone=CONCAT(
LEFT(phone,3),'-',
MID(phone,4,3),'-',
RIGHT(phone,4))
WHERE LENGTH(phone)=10;

SELECT registration_date 
FROM users1 LIMIT 10;

ALTER TABLE users1 ADD COLUMN Zip_code varchar(10);

SELECT address,
trim(SUBSTRING_INDEX(address,' ',-2))
FROM users1;

UPDATE users1
 SET zip_code=TRIM(SUBSTRING_INDEX(address,' ',-2));

SELECT address,
TRIM(SUBSTRING(address,1,LENGTH(address) - LENGTH(zip_code) - 2)) AS new
FROM users1;

UPDATE users1
TRIM(SUBSTRING(address,1,LENGTH(address) - LENGTH(zip_code) - 2));

UPDATE  support_tickets 
SET status=CONCAT(
UPPER(SUBSTRING(status,1,1)),LOWER(SUBSTRING(status,2)));

SELECT 
SUM(CASE WHEN user_id IS NULL then 1 ELSE 0 end)AS missing_user_id,
SUM(CASE WHEN ticket_id IS NULL then 1 ELSE 0 end)AS missing_ticket_id,
SUM(CASE WHEN issue IS NULL then 1 ELSE 0 end)AS missing_issue,
SUM(CASE WHEN status IS NULL then 1 ELSE 0 end)AS missing_status,
SUM(CASE WHEN created_at IS NULL then 1 ELSE 0 end)AS missing_created_at
FROM support_tickets;

SELECT 
SUM(CASE WHEN user_id IS NULL then 1 ELSE 0 end)AS missing_user_id,
SUM(CASE WHEN transaction_id IS NULL then 1 ELSE 0 end)AS missing_transaction_id,
SUM(CASE WHEN amount IS NULL then 1 ELSE 0 end)AS missing_amount,
SUM(CASE WHEN transaction_type IS NULL then 1 ELSE 0 end)AS missing_transaction_type,
SUM(CASE WHEN transaction_date IS NULL then 1 ELSE 0 end)AS missing_transaction_date
FROM transactions;

SELECT*FROM transactions;

ROLLBACK;
SET autocommit=0;
START TRANSACTION;

COMMIT;
