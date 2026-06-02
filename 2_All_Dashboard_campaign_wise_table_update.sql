-- =====================================================
-- DASHBOARD 1
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard1_anchor` AS

WITH campaign_base AS (

SELECT
    utm_key,
    ANY_VALUE(Month) AS Month,
    ANY_VALUE(Business) AS Business,
    ANY_VALUE(Channel) AS Channel,
    ANY_VALUE(Master_Campaign_Name) AS Master_Campaign_Name,
    MIN(Sent_Date_clean) AS Sent_Date,
    ANY_VALUE(Brand_Name) AS Brand_Name,
    ANY_VALUE(UTM_Campaign_Name) AS UTM_Campaign_Name,

    SUM(Sent) AS Sent,
    SUM(Delivered) AS Delivered,
    SUM(Open_Count) AS Opened,
    SUM(Click_Count) AS Clicked,
    SUM(Cost) AS Cost

FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`

GROUP BY utm_key
),

lead_agg AS (

SELECT 
    utm_key,
    COUNT(DISTINCT Lead_Id) AS Lead

FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_internal`

GROUP BY utm_key
),

invoice_agg AS (

SELECT
    utm_key,

    -- ✅ SKU-level sale (safe)
    COUNT(DISTINCT CONCAT(Invoice_number, Invoice_model_number)) AS Sale,

    SUM(Invoice_billing_amount) AS Revenue

FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal`

GROUP BY utm_key
)

SELECT

c.Month,
c.Business,
c.Channel,
c.Master_Campaign_Name,
c.Sent_Date,
c.Brand_Name,
c.UTM_Campaign_Name,

c.Sent,
c.Delivered,
c.Opened,
c.Clicked,
c.Cost,

IFNULL(l.Lead,0) AS Lead,
IFNULL(i.Sale,0) AS Sale,
IFNULL(i.Revenue,0) AS Revenue,

SAFE_DIVIDE(IFNULL(i.Revenue,0), c.Cost) AS ROAS

FROM campaign_base c

LEFT JOIN lead_agg l
ON c.utm_key = l.utm_key

LEFT JOIN invoice_agg i
ON c.utm_key = i.utm_key;


-- =====================================================
-- DASHBOARD 2
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard2_aging` AS

WITH campaign_base AS (
  SELECT
    utm_key,
    ANY_VALUE(Month) AS Month,
    ANY_VALUE(Business) AS Business,
    ANY_VALUE(Channel) AS Channel,
    ANY_VALUE(Master_Campaign_Name) AS Master_Campaign_Name,
    MIN(Sent_Date_clean) AS Sent_Date
  FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`
  GROUP BY utm_key
),

lead_bucket AS (
  SELECT
    c.Month,
    c.Business,
    c.Channel,
    c.Master_Campaign_Name,
    c.Sent_Date,

    CASE
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) < 0 THEN 'Pre-Campaign'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 0 AND 1 THEN 'D0-D1'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 2 AND 7 THEN 'D2-D7'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 8 AND 15 THEN 'D8-D15'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 16 AND 30 THEN 'D16-D30'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 31 AND 45 THEN 'D31-D45'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 46 AND 60 THEN 'D46-D60'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 61 AND 75 THEN 'D61-D75'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 76 AND 90 THEN 'D76-D90'
      ELSE 'D90+'
    END AS Aging_Bucket,

    CASE
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) < 0 THEN 0
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 0 AND 1 THEN 1
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 2 AND 7 THEN 2
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 8 AND 15 THEN 3
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 16 AND 30 THEN 4
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 31 AND 45 THEN 5
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 46 AND 60 THEN 6
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 61 AND 75 THEN 7
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 76 AND 90 THEN 8
      ELSE 9
    END AS Bucket_Order,

    COUNT(DISTINCT l.Lead_Id) AS Lead

  FROM campaign_base c
  LEFT JOIN `whatsappanalysis-487206.Best_day_time.Lead_Data_internal` l
    ON c.utm_key = l.utm_key

  GROUP BY
    Month, Business, Channel, Master_Campaign_Name, Sent_Date, Aging_Bucket, Bucket_Order
),

invoice_bucket AS (
  SELECT
    c.Month,
    c.Business,
    c.Channel,
    c.Master_Campaign_Name,
    c.Sent_Date,

    CASE
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) < 0 THEN 'Pre-Campaign'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 0 AND 1 THEN 'D0-D1'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 2 AND 7 THEN 'D2-D7'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 8 AND 15 THEN 'D8-D15'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 16 AND 30 THEN 'D16-D30'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 31 AND 45 THEN 'D31-D45'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 46 AND 60 THEN 'D46-D60'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 61 AND 75 THEN 'D61-D75'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 76 AND 90 THEN 'D76-D90'
      ELSE 'D90+'
    END AS Aging_Bucket,

    CASE
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) < 0 THEN 0
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 0 AND 1 THEN 1
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 2 AND 7 THEN 2
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 8 AND 15 THEN 3
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 16 AND 30 THEN 4
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 31 AND 45 THEN 5
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 46 AND 60 THEN 6
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 61 AND 75 THEN 7
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 76 AND 90 THEN 8
      ELSE 9
    END AS Bucket_Order,

    -- ✅ ONLY CHANGE (SKU-level, null-safe)
    COUNT(DISTINCT CONCAT(i.Invoice_number, '_', IFNULL(i.Invoice_model_number,'NA'))) AS Sale,

    -- ❗ NO CHANGE
    SUM(i.Invoice_billing_amount) AS Revenue

  FROM campaign_base c
  LEFT JOIN `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal` i
    ON c.utm_key = i.utm_key

  GROUP BY
    Month, Business, Channel, Master_Campaign_Name, Sent_Date, Aging_Bucket, Bucket_Order
)

SELECT
  COALESCE(l.Month, s.Month) AS Month,
  COALESCE(l.Business, s.Business) AS Business,
  COALESCE(l.Channel, s.Channel) AS Channel,
  COALESCE(l.Master_Campaign_Name, s.Master_Campaign_Name) AS Master_Campaign_Name,
  COALESCE(l.Sent_Date, s.Sent_Date) AS Sent_Date,
  COALESCE(l.Aging_Bucket, s.Aging_Bucket) AS Aging_Bucket,
  COALESCE(l.Bucket_Order, s.Bucket_Order) AS Bucket_Order,

  IFNULL(l.Lead,0) AS Lead,
  IFNULL(s.Sale,0) AS Sale,
  IFNULL(s.Revenue,0) AS Revenue,

  SAFE_DIVIDE(IFNULL(s.Sale,0), IFNULL(l.Lead,0)) AS Conversion_Rate,
  SAFE_DIVIDE(IFNULL(s.Revenue,0), IFNULL(s.Sale,0)) AS AOV

FROM lead_bucket l
FULL OUTER JOIN invoice_bucket s
ON l.Master_Campaign_Name = s.Master_Campaign_Name
AND l.Aging_Bucket = s.Aging_Bucket
AND l.Sent_Date = s.Sent_Date;

-- =====================================================
-- DASHBOARD 3
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard3_brand` AS

-- 1️⃣ Campaign anchor
WITH campaign_base AS (

SELECT
    utm_key,
    ANY_VALUE(Month) AS Month,
    ANY_VALUE(Business) AS Business,
    ANY_VALUE(Channel) AS Channel,
    ANY_VALUE(Master_Campaign_Name) AS Master_Campaign_Name,
    MIN(Sent_Date_clean) AS Sent_Date,
    ANY_VALUE(Brand_Name) AS Primary_Brand

FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`

GROUP BY utm_key
),

-- 2️⃣ Lead metrics by Lead Brand
lead_brand AS (

SELECT
    utm_key,
    INITCAP(TRIM(Lead_Brand)) AS Brand_Name,

    COUNT(DISTINCT Lead_Id) AS Total_Lead,

    COUNT(DISTINCT CASE WHEN LOWER(Lead_Status)='open' THEN Lead_Id END) AS Open_Lead,
    COUNT(DISTINCT CASE WHEN LOWER(Lead_Status)='qualified' THEN Lead_Id END) AS Qualified_Lead,
    COUNT(DISTINCT CASE WHEN LOWER(Lead_Status)='unqualified' THEN Lead_Id END) AS Unqualified_Lead

FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_internal`

GROUP BY utm_key, Brand_Name
),

-- 3️⃣ Sale & Revenue by Invoice Brand
invoice_brand AS (

SELECT
    utm_key,
    INITCAP(TRIM(Invoice_brand_name)) AS Brand_Name,

    -- ✅ ONLY CHANGE (SKU-level safe)
    COUNT(DISTINCT CONCAT(Invoice_number, '_', IFNULL(Invoice_model_number,'NA'))) AS Total_Sale,

    -- ❗ NO CHANGE
    SUM(Invoice_billing_amount) AS Revenue

FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal`

GROUP BY utm_key, Brand_Name
),

-- 4️⃣ Merge lead brand & invoice brand metrics
brand_metrics AS (

SELECT
    COALESCE(l.utm_key,i.utm_key) AS utm_key,
    COALESCE(l.Brand_Name,i.Brand_Name) AS Brand_Name,

    IFNULL(l.Total_Lead,0) AS Total_Lead,
    IFNULL(i.Total_Sale,0) AS Total_Sale,
    IFNULL(i.Revenue,0) AS Revenue,

    IFNULL(l.Open_Lead,0) AS Open_Lead,
    IFNULL(l.Qualified_Lead,0) AS Qualified_Lead,
    IFNULL(l.Unqualified_Lead,0) AS Unqualified_Lead

FROM lead_brand l

FULL OUTER JOIN invoice_brand i
ON l.utm_key = i.utm_key
AND l.Brand_Name = i.Brand_Name
)

-- 5️⃣ Final output
SELECT

    c.Month,
    c.Business,
    c.Channel,
    c.Master_Campaign_Name,
    c.Sent_Date,
    c.Primary_Brand,

    b.Brand_Name,

    b.Total_Lead,
    b.Total_Sale,
    b.Revenue,

    b.Open_Lead,
    b.Qualified_Lead,
    b.Unqualified_Lead,

    SAFE_DIVIDE(b.Qualified_Lead,b.Total_Lead) AS Qualified_Pct,
    SAFE_DIVIDE(b.Open_Lead,b.Total_Lead) AS Open_Pct,
    SAFE_DIVIDE(b.Unqualified_Lead,b.Total_Lead) AS Unqualified_Pct

FROM campaign_base c

LEFT JOIN brand_metrics b
ON c.utm_key = b.utm_key;


-- =====================================================
-- DASHBOARD 4
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard4_conversion_curve` AS

WITH campaign_base AS (

SELECT
    utm_key,
    ANY_VALUE(Master_Campaign_Name) AS Master_Campaign_Name
FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`
GROUP BY utm_key

),

lead_base AS (

SELECT
    Lead_Id,
    utm_key,
    Lead_Date
FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_internal`
WHERE Lead_Date IS NOT NULL

),

invoice_base AS (

SELECT
    utm_key,
    Invoice_number AS invoice_number,
    Invoice_model_number AS invoice_model_number,   -- ✅ ADDED
    Invoice_Date

FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal`
WHERE Invoice_Date IS NOT NULL

),

joined AS (

SELECT
    c.Master_Campaign_Name,

    CASE
        WHEN DATE_DIFF(i.Invoice_Date, l.Lead_Date, DAY) < 1 THEN 1
        ELSE DATE_DIFF(i.Invoice_Date, l.Lead_Date, DAY)
    END AS conversion_days,

    l.Lead_Id,
    i.invoice_number,
    i.invoice_model_number   -- ✅ ADDED

FROM lead_base l

JOIN invoice_base i
ON l.utm_key = i.utm_key

LEFT JOIN campaign_base c
ON l.utm_key = c.utm_key

),

daily_conversion AS (

SELECT
    Master_Campaign_Name,
    conversion_days,

    -- ✅ SKU-level conversion (safe)
    COUNT(DISTINCT CONCAT(invoice_number, '_', IFNULL(invoice_model_number,'NA'))) AS conversions

FROM joined
GROUP BY Master_Campaign_Name, conversion_days

),

total_leads AS (

SELECT
    c.Master_Campaign_Name,
    COUNT(DISTINCT l.Lead_Id) AS total_leads

FROM lead_base l
LEFT JOIN campaign_base c
ON l.utm_key = c.utm_key
GROUP BY c.Master_Campaign_Name

),

final AS (

SELECT
    d.Master_Campaign_Name,
    d.conversion_days,
    d.conversions,

    SUM(d.conversions) OVER(
        PARTITION BY d.Master_Campaign_Name
        ORDER BY d.conversion_days
    ) AS cumulative_conversions,

    t.total_leads

FROM daily_conversion d
LEFT JOIN total_leads t
ON d.Master_Campaign_Name = t.Master_Campaign_Name

)

SELECT
Master_Campaign_Name,
conversion_days,
conversions,
cumulative_conversions,
SAFE_DIVIDE(cumulative_conversions,total_leads) AS cumulative_conversion_pct

FROM final
ORDER BY Master_Campaign_Name, conversion_days;
-- =====================================================
-- DASHBOARD 5
-- =====================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard5_current_vs_rolling_metric` AS

WITH campaign_map AS (
  SELECT
    utm_key,
    ANY_VALUE(Master_Campaign_Name) AS Master_Campaign_Name,
    MIN(Sent_Date_clean) AS Sent_Date
  FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`
  GROUP BY utm_key
),

-- Lead & Cost (always current)
lead_cost AS (
  SELECT
    Master_Campaign_Name,
    SUM(Lead) AS Current_Lead,
    SUM(Cost) AS Current_Cost
  FROM `whatsappanalysis-487206.Best_day_time.dashboard1_anchor`
  GROUP BY Master_Campaign_Name
),

-- Split invoices into current vs rolling
invoice_split AS (
  SELECT
    cm.Master_Campaign_Name,

    -- ✅ Current Sale (SKU-level)
    COUNT(DISTINCT CASE
      WHEN i.Invoice_Date <= LAST_DAY(cm.Sent_Date)
      THEN CONCAT(i.Invoice_number, '_', IFNULL(i.Invoice_model_number,'NA'))
    END) AS Current_Sale,

    -- ❗ NO CHANGE
    SUM(CASE
      WHEN i.Invoice_Date <= LAST_DAY(cm.Sent_Date)
      THEN i.Invoice_billing_amount
    END) AS Current_Revenue,

    -- ✅ Rolling Sale (SKU-level)
    COUNT(DISTINCT CASE
      WHEN i.Invoice_Date > LAST_DAY(cm.Sent_Date)
      THEN CONCAT(i.Invoice_number, '_', IFNULL(i.Invoice_model_number,'NA'))
    END) AS Rolling_Sale,

    -- ❗ NO CHANGE
    SUM(CASE
      WHEN i.Invoice_Date > LAST_DAY(cm.Sent_Date)
      THEN i.Invoice_billing_amount
    END) AS Rolling_Revenue

  FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal` i
  LEFT JOIN campaign_map cm
    ON i.utm_key = cm.utm_key
  GROUP BY cm.Master_Campaign_Name
),

base AS (
  SELECT
    lc.Master_Campaign_Name,
    lc.Current_Lead,
    lc.Current_Cost,
    IFNULL(i.Current_Sale,0) AS Current_Sale,
    IFNULL(i.Current_Revenue,0) AS Current_Revenue,
    IFNULL(i.Rolling_Sale,0) AS Rolling_Sale,
    IFNULL(i.Rolling_Revenue,0) AS Rolling_Revenue
  FROM lead_cost lc
  LEFT JOIN invoice_split i
    ON lc.Master_Campaign_Name = i.Master_Campaign_Name
)

-- Lead
SELECT Master_Campaign_Name,1 Metric_Order,'Lead' Metric,
NULLIF(Current_Lead,0) Current_Value,
NULL Rolling_Value,
NULL Delta_Value,
Current_Lead Total_Value
FROM base

UNION ALL

-- Cost
SELECT Master_Campaign_Name,2,'Cost',
NULLIF(Current_Cost,0),
NULL,
NULL,
Current_Cost
FROM base

UNION ALL

-- Sale
SELECT Master_Campaign_Name,3,'Sale',
NULLIF(Current_Sale,0),
NULLIF(Rolling_Sale,0),
NULLIF(Rolling_Sale,0),
Current_Sale + Rolling_Sale
FROM base

UNION ALL

-- Revenue
SELECT Master_Campaign_Name,4,'Revenue',
NULLIF(Current_Revenue,0),
NULLIF(Rolling_Revenue,0),
NULLIF(Rolling_Revenue,0),
Current_Revenue + Rolling_Revenue
FROM base

UNION ALL

-- Current L2S
SELECT Master_Campaign_Name,5,'Current L2S',
SAFE_DIVIDE(Current_Sale,Current_Lead),
NULL,
NULL,
SAFE_DIVIDE(Current_Sale,Current_Lead)
FROM base

UNION ALL

-- Rolling L2S
SELECT Master_Campaign_Name,6,'Rolling L2S',
NULL,
CASE WHEN Rolling_Sale>0 THEN SAFE_DIVIDE(Rolling_Sale,Current_Lead) END,
NULL,
SAFE_DIVIDE(Current_Sale+Rolling_Sale,Current_Lead)
FROM base

UNION ALL

-- ROAS
SELECT Master_Campaign_Name,7,'ROAS',
SAFE_DIVIDE(Current_Revenue,Current_Cost),
CASE WHEN Rolling_Revenue>0 THEN SAFE_DIVIDE(Rolling_Revenue,Current_Cost) END,
CASE WHEN Rolling_Revenue>0 THEN SAFE_DIVIDE(Rolling_Revenue,Current_Cost) END,
SAFE_DIVIDE(Current_Revenue+Rolling_Revenue,Current_Cost)
FROM base

UNION ALL

-- AOV
SELECT Master_Campaign_Name,8,'AOV',
SAFE_DIVIDE(Current_Revenue,Current_Sale),
CASE WHEN Rolling_Sale>0 THEN SAFE_DIVIDE(Rolling_Revenue,Rolling_Sale) END,
CASE WHEN Rolling_Sale>0 THEN SAFE_DIVIDE(Rolling_Revenue,Rolling_Sale) END,
SAFE_DIVIDE(Current_Revenue+Rolling_Revenue,Current_Sale+Rolling_Sale)
FROM base

UNION ALL

-- CPL
SELECT Master_Campaign_Name,9,'CPL',
SAFE_DIVIDE(Current_Cost,Current_Lead),
NULL,
NULL,
SAFE_DIVIDE(Current_Cost,Current_Lead)
FROM base

UNION ALL

-- CPS
SELECT Master_Campaign_Name,10,'CPS',
SAFE_DIVIDE(Current_Cost,Current_Sale),
NULL,
NULL,
SAFE_DIVIDE(Current_Cost,Current_Sale)
FROM base;