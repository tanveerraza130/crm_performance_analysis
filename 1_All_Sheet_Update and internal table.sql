-- =====================================================
-- STEP 1: RECREATE EXTERNAL TABLES
-- =====================================================

-- Lead Table (NO CHANGE)
CREATE OR REPLACE EXTERNAL TABLE `whatsappanalysis-487206.Best_day_time.Lead_Data_fixed`
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1yLHIrrudJdmyKpuj0EZKzCn94WS0-VXWsQ6ggSTW-1E'],
  skip_leading_rows = 1,
  sheet_range = 'Lead_Data!A:U'
);

-- Campaign Table (NO CHANGE)
CREATE OR REPLACE EXTERNAL TABLE `whatsappanalysis-487206.Best_day_time.campaign_performance_fixed`
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1yLHIrrudJdmyKpuj0EZKzCn94WS0-VXWsQ6ggSTW-1E'],
  skip_leading_rows = 1,
  sheet_range = 'Campaign_Performance!A:P'
);

-- 🔥 Invoice Table (FIXED COLUMN ORDER)
CREATE OR REPLACE EXTERNAL TABLE `whatsappanalysis-487206.Best_day_time.Invoice_Data_fixed`
(
Lead_Number STRING,
lead_first_name STRING,
lead_email STRING,
lead_phone STRING,
city_name STRING,
created STRING,
close_date STRING,
lead_source STRING,
marketing_source STRING,
marketing_campaign STRING,
marketing_adgroup STRING,   -- ✅ FIXED
marketing_medium STRING,    -- ✅ FIXED
marketing_term STRING,
marketing_content STRING,
lead_os_name STRING,
Lead_Brand__brand_name STRING,
Brands__brand_name STRING,
model_number STRING,
Lead_Statuses STRING,
Lead_Sub_Statuses STRING,
Invoice_number STRING,
Invoice_costomer_number STRING,
Invoice_brand_name STRING,
Invoice_model_number STRING,
Invoice_billing_amount STRING,
Invoice_type STRING,
Date_of_invoice STRING,
Final_UTM_Campaign STRING
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1yLHIrrudJdmyKpuj0EZKzCn94WS0-VXWsQ6ggSTW-1E'],
  skip_leading_rows = 1,
  sheet_range = 'Invoice_Data!A:AB'
);

-- =====================================================
-- STEP 2: CLEAN LEAD INTERNAL TABLE (NO CHANGE)
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.Lead_Data_internal` AS

SELECT
*,

TRIM(LOWER(`Final_UTM_Campaign`)) AS utm_key,

COALESCE(
DATE(SAFE_CAST(Lead_Created_At AS TIMESTAMP)),
SAFE.PARSE_DATE('%d-%m-%Y', CAST(Lead_Created_At AS STRING))
) AS Lead_Date,

COALESCE(
DATE(SAFE_CAST(Close_Date AS TIMESTAMP)),
SAFE.PARSE_DATE('%d-%m-%Y', CAST(Close_Date AS STRING))
) AS Invoice_Date_clean

FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_fixed`;

-- =====================================================
-- STEP 3: CLEAN CAMPAIGN INTERNAL TABLE (NO CHANGE)
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.campaign_performance_internal` AS

SELECT
*,

TRIM(LOWER(UTM_Campaign_Name)) AS utm_key,
DATE(Sent_Date) AS Sent_Date_clean,
SAFE_CAST(Spend AS FLOAT64) AS Cost

FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_fixed`;

-- =====================================================
-- STEP 4: CLEAN INVOICE INTERNAL TABLE (NO LOGIC CHANGE)
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal` AS

SELECT

lead_first_name,
close_date,
lead_phone,
lead_email,
city_name,

marketing_source,
marketing_campaign,
marketing_medium,
lead_os_name,

created,
Lead_Statuses,
Lead_Sub_Statuses,

Invoice_costomer_number,
Invoice_number,

SAFE_CAST(Invoice_billing_amount AS FLOAT64) AS Invoice_billing_amount,

Invoice_type,
Invoice_brand_name,

COALESCE(
  DATE(SAFE_CAST(Date_of_invoice AS TIMESTAMP)),
  SAFE.PARSE_DATE('%d-%m-%Y', Date_of_invoice)
) AS Invoice_Date,

Invoice_model_number,
Brands__brand_name,
Lead_Brand__brand_name,

TRIM(LOWER(Final_UTM_Campaign)) AS utm_key,

-- ✅ NEW COLUMN (SAFE – NO IMPACT)
CASE 
  WHEN DATE_TRUNC(DATE(created), MONTH) = DATE_TRUNC(
        COALESCE(
          DATE(SAFE_CAST(Date_of_invoice AS TIMESTAMP)),
          SAFE.PARSE_DATE('%d-%m-%Y', Date_of_invoice)
        ), MONTH)
  THEN 'Current'
  ELSE 'Rolling'
END AS conversion_type_new

FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_fixed`;

-- =====================================================
-- STEP 5: CREATE INVOICE → CAMPAIGN MAPPING TABLE
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.invoice_campaign_mapping` AS

SELECT

CP.Master_Campaign_Name,
CP.UTM_Campaign_Name,
CP.utm_key,

I.Invoice_number,
I.Invoice_billing_amount,
I.Invoice_Date

FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal` I

LEFT JOIN `whatsappanalysis-487206.Best_day_time.campaign_performance_internal` CP
ON I.utm_key = CP.utm_key;