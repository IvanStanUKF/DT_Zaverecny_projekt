# **DT_Zaverecny_projekt**
Záverečný projekt z predmetu Databázové technológie, Autori: Ivan Stančiak, Maksym Kuryk

Tento repozitár predstavuje implementáciu ELT procesu v Snowflake a vytvorenie dátového skladu so schémou Star Schema. Projekt pracuje s **Credit/Debit Transactions: Fast Food and Quick Service Restaurants** datasetom. Projekt sa zameriava na preskúmanie uskutočnených transakcií.

---
## **1. Úvod a popis zdrojových dát**
Dataset Credit/Debit Transactions: Fast Food and Quick Service Restaurants bol zvolený, pretože poskytuje realistické transakčné dáta, ktoré umožňujú analyzovať správanie zákazníkov, trendy nákupov, výkon prevádzok a demografické vzorce držiteľov kariet. Je ideálny na tvorbu hviezdicovej schémy a vizualizáciu kľúčových metrík v oblasti rýchleho občerstvenia.

V tomto projekte analyzujeme dáta o transakciách, zákazníkoch a obhcodníkoch. Cieľom je porozumieť:
- kde sa transakcie uskutočňujú,
- kedy sa transakcie uskutočňujú,
- v akom množstve sa transakcie uskutočnujú,
- popularite a tržbám obchodníkov,
- transakciám zákazníkov.
  
Zdrojové dáta pochádzajú zo Snowflake marketplace datasetu dostupného [tu](https://app.snowflake.com/marketplace/listing/GZSTZ708I0X/facteus-credit-debit-transactions-fast-food-and-quick-service-restaurants?search=fast%20food). Dataset obsahuje jednu hlavnú tabuľku:
- `QSR_TRANSACTIONS_SAMPLE` - dáta o transakciách (v našej databáze sme to pomenovali `raw_data`)

Účelom ELT procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre analýzu.

---
### **1.1 Dátová architektúra**

### **ERD diagram**
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na **entitno-relačnom diagrame (ERD)**:

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaveracny_projekt/blob/main/img/erd_diagram.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1 Entitno-relačná schéma Credit/Debit Transactions: Fast Food and Quick Service Restaurants</em>
</p>

---
## **2 Dimenzionálny model**

V ukážke bola navrhnutá **schéma hviezdy (star schema)** podľa Kimballovej metodológie, ktorá obsahuje 1 tabuľku faktov **`fact_transaction`**, ktorá je prepojená s nasledujúcimi 4 dimenziami:
- **`dim_card`**: Obsahuje podrobné údaje o kartách a ich vlastníkoch (číslo karty, typ karty, id účtu, generácia a vek držiteľa karty). Vzťah k tabuľke faktov: PK dim_cardId (dim_card) - CK cardId (fact_transaction).
- **`dim_merchant`**: Obsahuje podrobné údaje o obchodníkoch (názov obchodníka, lokácia prevádzky, kategórie). Vzťah k tabuľke faktov: PK dim_merchantId (dim_merchant) - CK merchantId (fact_transaction).
- **`dim_date`**: Zahrňuje informácie o dátumoch hodnotení (dátum, deň, deň v týždni, mesiac, rok). Vzťah k tabuľke faktov: PK dim_dateId (dim_date) - CK dateId (fact_transaction).
- **`dim_time`**: Obsahuje podrobné časové údaje (čas, hodina, minúta, sekunda). Vzťah k tabuľke faktov: PK dim_timeId (dim_eime) - CK timeId (fact_transaction).

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaveracny_projekt/blob/main/img/star_shema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre Credit/Debit Transactions: Fast Food and Quick Service Restaurants</em>
</p>

---
## **3. ELT proces v Snowflake**
ETL proces pozostáva z troch hlavných fáz: `extrahovanie` (Extract), `načítanie` (Load) a `transformácia` (Transform). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### **3.1 Extract (Extrahovanie dát)**
Dáta zo zdrojového datasetu (nachádzajúceho sa na Snowflake marketplace) boli najprv nahraté do Snowflake prostredníctvom Snowflake marketplace (cez tlačidlo Get) - databáza.schéma: CREDITDEBIT_TRANSACTIONS_FAST_FOOD_AND_QUICK_SERVICE_RESTAURANTS.SNOWFLAKE_MARKETPLACE. 
Kontrola extrahovania údajov a vytvorenie schémy projektu boli zabezpečené príkazmi:

#### Príklad kódu:
```sql
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
```

---
### **3.2 Load (Načítanie dát)**

Následne boli tieto dáta nahrané do našej vlastnej databázy (tabuľka: raw_data) a následne skontrolované nasledujúcimi príkazmi:

#### Príklad kódu:
```sql
/* ELT - Load */
CREATE OR REPLACE TABLE raw_data AS
SELECT * FROM CREDITDEBIT_TRANSACTIONS_FAST_FOOD_AND_QUICK_SERVICE_RESTAURANTS.SNOWFLAKE_MARKETPLACE.QSR_TRANSACTIONS_SAMPLE;

SELECT * FROM raw_data LIMIT 100;
DESCRIBE TABLE raw_data;
```

---
### **3.3 Transform (Transformácia dát)**

V tejto fáze boli dáta z pôvodnej tabuľky vyčistené a transformované. Hlavným cieľom bolo pripraviť dimenzie a faktovú tabuľku, ktoré umožnia jednoduchú a efektívnu analýzu. Dimenzie boli navrhnuté na poskytovanie kontextu pre faktovú tabuľku. 
Transformácia zahŕňala získanie jedinečných riadkov pre každú dimenziu (dim_card, dim_merchant, dim_date, dim_time) a zároveň tvorbu jedinečného PK typu INT cez Window function s ROW_NUMBER() pre každú dimenziu a faktovú tabuľku. 

`dim_card` obsahuje podrobné údaje o kartách a ich vlastníkoch (číslo karty, typ karty, id účtu, generácia a vek držiteľa karty). Táto dimenzia je `typu SCD 0`, čiže neumožňuje sledovať historické zmeny v údajoch o karte a vlastníkovi karty.

#### Príklad kódu:
```sql
/* ELT - Transform */

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
```

Podobne `dim_merchant` obsahuje podrobné údaje o obchodníkoch (názov obchodníka, lokácia prevádzky, kategórie). Táto dimenzia je `typu SCD 0`, čiže neumožňuje sledovať historické zmeny v údajoch o obchodníkoch a prevádzkach. 

#### Príklad kódu:
```sql
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
```

Dimenzie `dim_date` a `dim_time` sú navrhnuté tak, aby uchovávali informácie o dátumoch a časoch uskutočnenia transakcií. Obsahuje odvodené údaje, ako sú deň, deň v týždni, mesiac, rok (pre dim_date) a hodina, minúta, sekunda (pre dim_time). Tieto dimenzie sú štruktúrované tak, aby umožňovali podrobné dátumové a časové analýzy, ako sú počty a sumy transakcií za dni, dni v týždni, mesiace, hodiny, minúty, sekundy. Z hľadiska SCD sú tieto dimenzie klasifikované ako `SCD Typ 0`. To znamená, že existujúce záznamy v týchto dimenziách sú nemenné a uchovávajú statické informácie.

#### Príklad kódu:
```sql
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
```

Pred vytvorením faktovej tabuľky bolo nutné nahradiť hodnoty NULL v dim_merchant.store_id na '-1' kvôli správnemu vytvoreniu faktovej tabuľky na základe spájania cez INNER JOIN.

Faktová tabuľka `fact_transaction` obsahuje záznamy o transakciách a prepojenia na všetky dimenzie. Obsahuje kľúčové metriky, ako je číslo transakcie, suma transakcie, typ transakcie, miesto transakciel, atď.

#### Príklad kódu:
```sql
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
```

ELT proces v Snowflake umožnil spracovanie pôvodných dát z pôvodnej tabuľky do viacdimenzionálneho modelu typu hviezda. Tento proces zahŕňal čistenie, obohacovanie a reorganizáciu údajov. Výsledný model umožňuje analýzu ustutočnených transakcií, obchodníkov a zákazníkov.

Po úspešnom vytvorení dimenzií a faktovej tabuľky boli dáta nahraté do finálnej štruktúry. Na záver bola pôvodná tabuľka so surovými dátami (raw_data) odstránená:

#### Príklad kódu:
```sql
// Odstránenie pôvodnej tabuľky
DROP TABLE IF EXISTS raw_data;
```

---
## **4 Vizualizácia dát**

Dashboard obsahuje `6 vizualizácií`, ktoré poskytujú základný prehľad o kľúčových metrikách týkajúcich sa uskutočnených platieb v danom štáte za dané časové obdobie. Tieto vizualizácie odpovedajú na dôležité otázky a umožňujú lepšie pochopiť rozsah uskutočnených platieb.

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaverecny_projekt/blob/main/img/DT_Záverečný-projekt_Dashboard.png" alt="Dashboard">
  <br>
  <em>Obrázok 3 Dashboard Credit/Debit Transactions: Fast Food and Quick Service Restaurants datasetu</em>
</p>

---
### **Graf 1: Počet transakcií na US štát (top 8)**
Graf zobrazuje 8 štátov v USA s najväčším počtom transakcií. 
Z údajov je možné identifikovať štáty v USA s najväčším počtom transakcií. 
Z údajov je možné pozorovať, že štát `TX` má výrazne najviac transakcií v tomto odvetví. 
Tieto údaje môžu byť výrazne užitočné pri výbere sídla podniku.

```sql
/* Graf 1: Počet transakcií na US štát (top 8) */

SELECT 
    state AS state,
    COUNT(state) AS total_transactions_by_state
FROM fact_transaction
GROUP BY state
ORDER BY total_transactions_by_state DESC
LIMIT 8;
```

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaverecny_projekt/blob/main/img/DT_ZP_Graf1.png" alt="Graf1">
  <br>
  <em>Obrázok 4 Dashboard Graf 1</em>
</p>

---
### **Graf 2: Počet transakcií podľa hodiny dňa**
Graf znázorňuje rozdiely v počte transakcií na základe jednotlivých hodín dňa. 
Z údajov je možné identifikovať časy počas dňa, kedy sa uskutočnuje najviac a najmenej platieb. 
Z údajov je možné pozorovať, že najväčší počet transakcií sa uskutočnuje `večer a v noci`, zatiaľ čo najmenší počet transakcií sa uskutočnuje `ráno`.
Tieto údaje môžu byť výrazne užitočné pri optimalizácii prevádzkových hodín tak, aby bola čo najvyššia tržba.

```sql
/* Graf 2: Počet transakcií podľa hodiny dňa */

SELECT
    t.hour AS hour,
    COUNT(f.fact_transactionId) AS total_transactions_by_hour
FROM fact_transaction f
INNER JOIN dim_time t ON f.timeId = t.dim_timeId
GROUP BY t.hour
ORDER BY t.hour ASC;
```

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaverecny_projekt/blob/main/img/DT_ZP_Graf2.png" alt="Graf2">
  <br>
  <em>Obrázok 5 Dashboard Graf 2</em>
</p>

---
### **Graf 3: Počet a celková suma transakcií podľa dňa v týždni**
Graf ukazuje, ako sa počet transakcií a celková výška tržieb líšia v jednotlivých dňoch týždňa. 
Z údajov je možné identifikovať dni s najvyššou a najnižšou nákupnou aktivitou. 
Z údajov je možné pozorovať, že najvyššia nákupná aktivita je zvyčajne `od stredy do soboty`, zatiaľ čo najnižšia nákupná aktivita je zvyčajne `od nedeľe do utorka`.
Tieto údaje môžu byť výrazne užitočné pri optimalizácii prevádzkových dní tak, aby bola čo najvyššia tržba.

```sql
/* Graf 3: Počet a celková suma transakcií podľa dňa v týždni */

SELECT
    d.weekday_name AS weekday,
    SUM(f.transaction_amount) AS total_spend_by_weekday,
    COUNT(f.fact_transactionId) AS total_transactions_by_weekday
FROM fact_transaction f
INNER JOIN dim_date d ON f.dateId = d.dim_dateId
GROUP BY d.weekday_name, d.weekday
ORDER BY d.weekday ASC;
```

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaverecny_projekt/blob/main/img/DT_ZP_Graf3.png" alt="Graf3">
  <br>
  <em>Obrázok 6 Dashboard Graf 3</em>
</p>

---
### **Graf 4: Priemerná tržba na 1 prevádzku podľa kategórie3 (počet prevádzok > 1000)**
Graf zobrazuje priemernú tržbu na jednu prevádzku podľa obchodnej kategórie (Category 3). 
Z údajov je možné identifikovať kategórie s najvyššou výkonnosťou na úrovni jednotlivých prevádzok v priemere. Zahrnuté sú len kategórie s viac ako 1000 prevádzkami, aby boli výsledky štatisticky viac relevantné. 
Z údajov je možné pozorovať, že najväčšia nákupná aktivita je pre podniky v kategórii `Coffee/Tea (nápoje)`.
Tieto údaje môžu byť výrazne užitočné pri výbere podnikového zamerania.

```sql
/* Graf 4: Priemerná tržba na 1 prevádzku podľa kategórie3 (počet prevádzok > 1000) */

SELECT
    m.category3,
    COUNT(DISTINCT m.store_id) AS total_stores,
    SUM(f.transaction_amount) AS total_transaction_amount,
    total_transaction_amount / total_stores AS average_store_transaction_amount_by_category3
FROM fact_transaction f
INNER JOIN dim_merchant m ON f.merchantId = m.dim_merchantId
GROUP BY m.category3
HAVING total_stores > 1000
ORDER BY total_stores ASC;
```

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaverecny_projekt/blob/main/img/DT_ZP_Graf4.png" alt="Graf4">
  <br>
  <em>Obrázok 7 Dashboard Graf 4</em>
</p>

---
### **Graf 5: Popularita podľa generácií držiteľov kariet**
Graf zobrazuje počet transakcií podľa generácií držiteľov kariet. 
Z údajov je možné identifikovať vekové generácie s najvyššiou a najnižšou nákupnou aktivitou. 
Z údajov je možné pozorovať, že najvyššiu nákupnú aktivitu vykazuje generácia `Millennial` a najmenšiu nákupnú aktivitu vykazuje generácia `Silent`. 
Tieto údaje môžu byť výrazne užitočné pri výbere marketingovej propagácie a stratégie.

```sql
/* Graf 5: Popularita podľa generácií držiteľov kariet */

SELECT
    c.cardholder_generation AS generation,
    COUNT(f.fact_transactionId) AS total_transactions_by_generation
FROM fact_transaction f
INNER JOIN dim_card c ON f.cardId = c.dim_cardId
GROUP BY c.cardholder_generation
ORDER BY total_transactions_by_generation DESC;
```

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaverecny_projekt/blob/main/img/DT_ZP_Graf5.png" alt="Graf5">
  <br>
  <em>Obrázok 8 Dashboard Graf 5</em>
</p>

---
### **Graf 6: Priemerná výška transakcie podľa kategórie1**
Graf zobrazuje priemernú výšku transakcie podľa hlavnej kategórie obchodníka (kategória 1). 
Z údajov je možné identifikovať a pozorovať, akú priemernú výšku transakcie vykazujú transakcie v daných kategóriách. 
Tieto údaje môžu byť výrazne užitočné pri poskytovaní finančných služieb a marketingových stratégií.

```sql
/* Graf 6: Priemerná výška transakcie podľa kategórie1 */

SELECT
    m.category1,
    AVG(f.transaction_amount) AS avg_transaction_amount_by_category1
FROM fact_transaction f
JOIN dim_merchant m ON f.merchantId = m.dim_merchantId
GROUP BY m.category1
ORDER BY avg_transaction_amount_by_category1 DESC;
```

<p align="center">
  <img src="https://github.com/IvanStanUKF/DT_Zaverecny_projekt/blob/main/img/DT_ZP_Graf6.png" alt="Graf6">
  <br>
  <em>Obrázok 9 Dashboard Graf 6</em>
</p>

Dashboard poskytuje komplexný pohľad na dáta, pričom zodpovedá dôležité otázky týkajúce sa rozsahu uskutočnených platieb. Vizualizácie umožňujú jednoduchú interpretáciu dát a môžu byť využité na optimalizáciu odporúčacích systémov, marketingových stratégií a gastronomických služieb.

---

**Autori:** Ivan Stančiak, Maksym Kuryk
