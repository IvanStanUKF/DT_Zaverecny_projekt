USE WAREHOUSE SPIDER_WH;
USE DATABASE CREDITDEBIT_TRANSACTIONS_FAST_FOOD_AND_QUICK_SERVICE_RESTAURANTS;
USE SCHEMA CREDITDEBIT_TRANSACTIONS_FAST_FOOD_AND_QUICK_SERVICE_RESTAURANTS.SNOWFLAKE_MARKETPLACE;

/* Kontrola Extrahovania údajov */
SELECT * FROM QSR_TRANSACTIONS_SAMPLE LIMIT 100;
DESCRIBE TABLE QSR_TRANSACTIONS_SAMPLE;

/* Vytvorenie schémy projektu */
USE DATABASE SPIDER_DB;
CREATE OR REPLACE SCHEMA SPIDER_DB.ZAVERECNY_PROJEKT;
USE SCHEMA SPIDER_DB.ZAVERECNY_PROJEKT;

/* ELT - Load */
CREATE OR REPLACE TABLE raw_data AS
SELECT * FROM CREDITDEBIT_TRANSACTIONS_FAST_FOOD_AND_QUICK_SERVICE_RESTAURANTS.SNOWFLAKE_MARKETPLACE.QSR_TRANSACTIONS_SAMPLE;

SELECT * FROM raw_data LIMIT 100;
DESCRIBE TABLE raw_data;





/* ELT - Transform */



// dim_merchant
CREATE OR REPLACE TABLE dim_merchant AS (
SELECT
    ROW_NUMBER() OVER (ORDER BY merchant_id, merchant_store_id) AS dim_merchantId,
    merchant_id AS merchant_number,
    merchant_name AS merchant_name,
    merchant_store_id AS store_id,
    merchant_store_location AS store_location,
    merchant_store_address AS store_address,
    merchant_category_level_1 AS category1,
    merchant_category_level_2 AS category2,
    merchant_category_level_3 AS category3
FROM (
    SELECT DISTINCT 
        merchant_id, 
        merchant_name,
        merchant_store_id, 
        merchant_store_location,
        merchant_store_address, 
        merchant_category_level_1,
        merchant_category_level_2, 
        merchant_category_level_3
    FROM raw_data
    )
ORDER BY dim_merchantId
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT dim_merchantId) AS distinct_values FROM dim_merchant;
SELECT * FROM dim_merchant ORDER BY dim_merchantid ASC LIMIT 100;
DESCRIBE TABLE dim_merchant;



// dim_card
CREATE OR REPLACE TABLE dim_card AS (
SELECT
    ROW_NUMBER() OVER (ORDER BY card_id ASC) AS dim_cardId,
    card_id AS card_number,
    card_type AS card_type,
    account_id AS account_id,
    card_holder_generation AS cardholder_generation,
    card_holder_vintage AS cardholder_age
FROM (
    SELECT DISTINCT 
        card_id, 
        card_type,
        account_id,
        card_holder_generation,
        card_holder_vintage
    FROM raw_data
    )
ORDER BY dim_cardId
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT dim_cardId) AS distinct_values FROM dim_card;
SELECT * FROM dim_card ORDER BY dim_cardId ASC LIMIT 100;
DESCRIBE TABLE dim_card;



// dim_time
CREATE OR REPLACE TABLE dim_time AS (
SELECT
    ROW_NUMBER() OVER (ORDER BY time_distinct ASC) AS dim_timeId,
    time_distinct AS time,
    HOUR(time_distinct) AS hour,
    MINUTE(time_distinct) AS minute,
    SECOND(time_distinct) AS second
FROM (
    SELECT DISTINCT 
        TIME(transaction_date)::TIME(0) AS time_distinct
    FROM raw_data
    )
ORDER BY dim_timeId
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT dim_timeId) AS distinct_values FROM dim_time;
SELECT * FROM dim_time ORDER BY dim_timeId ASC LIMIT 100;
DESCRIBE TABLE dim_time;



// dim_date
CREATE OR REPLACE TABLE dim_date AS (
SELECT
    ROW_NUMBER() OVER (ORDER BY date_distinct ASC) AS dim_dateId,
    date_distinct AS date,
    DAY(date_distinct) AS day,
    DAYOFWEEKISO(date_distinct) AS weekday,
    CASE DAYOFWEEKISO(date_distinct)
        WHEN 1 THEN 'Pondelok'
        WHEN 2 THEN 'Utorok'
        WHEN 3 THEN 'Streda'
        WHEN 4 THEN 'Štvrtok'
        WHEN 5 THEN 'Piatok'
        WHEN 6 THEN 'Sobota'
        WHEN 7 THEN 'Nedeľa'
    END AS weekday_name,
    MONTH(date_distinct) AS month,
    CASE MONTH(date_distinct)
        WHEN 1 THEN 'Január'
        WHEN 2 THEN 'Február'
        WHEN 3 THEN 'Marec'
        WHEN 4 THEN 'Apríl'
        WHEN 5 THEN 'Máj'
        WHEN 6 THEN 'Jún'
        WHEN 7 THEN 'Júl'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'Október'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END AS month_name,
    YEAR(date_distinct) AS year
FROM (
    SELECT DISTINCT 
        DATE(transaction_date) AS date_distinct
    FROM raw_data
    )
ORDER BY dim_dateId
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT dim_dateId) AS distinct_values FROM dim_date;
SELECT * FROM dim_date ORDER BY dim_dateId ASC;
DESCRIBE TABLE dim_date;



// fact_transaction
UPDATE dim_merchant
SET store_id = '-1'
WHERE store_id IS NULL;

CREATE OR REPLACE TABLE fact_transaction AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY rd.transaction_id) AS fact_transactionId,                           -- Vytvorenie jedinečnej hodnoty pre PK
        c.dim_cardId AS cardId,                                                                         -- CK pre PK tabuľky dim_card
        m.dim_merchantId AS merchantId,                                                                 -- CK pre PK tabuľky dim_merchant
        d.dim_dateId AS dateId,                                                                         -- CK pre PK tabuľky dim_date
        t.dim_timeId AS timeId,                                                                         -- CK pre PK tabuľky dim_time
        rd.transaction_id AS transaction_number,
        rd.gross_transaction_amount AS transaction_amount,
        rd.transaction_type AS transaction_type,
        rd.currency_code AS currency_code,
        rd.transaction_city AS city,
        rd.transaction_state AS state,
        rd.transaction_postal_code AS postal_code,
        rd.transaction_msa AS msa,
        rd.transaction_description AS description,
        COUNT(*) OVER (PARTITION BY c.dim_cardId) AS transaction_count,                                 -- Window funkcia pre zistenie počtu transakcií na kartu
        SUM(rd.gross_transaction_amount) OVER (PARTITION BY c.dim_cardId) AS total_spend_by_card,       -- Window funkcia pre zistenie sumy všetkých transakcií na kartu
        AVG(rd.gross_transaction_amount) OVER (PARTITION BY c.dim_cardId) AS average_spend_by_card      -- Window funkcia pre zistenie priemernej výšky transakcií na kartu
    FROM raw_data rd
    INNER JOIN dim_date d ON DATE(rd.transaction_date) = d.date                                         -- Prepojenie na základe dátumu z "transaction_date"
    INNER JOIN dim_time t ON TIME(rd.transaction_date)::TIME(0) = t.time                                -- Prepojenie na základe času z "transaction_date"
    INNER JOIN dim_card c ON rd.card_id = c.card_number                                                 -- Prepojenie na základe čísla karty z "card_id"
    INNER JOIN dim_merchant m ON rd.merchant_id = m.merchant_number AND (rd.merchant_store_id = m.store_id OR (rd.merchant_store_id IS NULL AND m.store_id LIKE '-1'))      -- Prepojenie na základe jedinečnej kombinácie merchant_id a merchant_store_id (NULL hodnota bola prepísaná na '-1' pomocou UPDATE kvôli funkčnosti)
);

-- Kontrola
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT fact_transactionId) AS distinct_values FROM fact_transaction;
SELECT * FROM fact_transaction ORDER BY fact_transactionId ASC;
DESCRIBE TABLE fact_transaction;

SELECT
    transaction_number,
    COUNT(*) AS count
FROM fact_transaction
GROUP BY transaction_number
HAVING COUNT(*) > 1;

// Odstránenie pôvodnej tabuľky
DROP TABLE IF EXISTS raw_data;