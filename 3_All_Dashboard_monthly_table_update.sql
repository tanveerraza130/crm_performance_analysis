-- ===============================================================================================================================================================
-- DASHBOARD 1
-- ===============================================================================================================================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard1_monthly` AS

-- =========================
-- 1️⃣ CRM LEAD (FINAL - VERIFIED)
-- =========================
WITH lead_kpi AS (
  SELECT
    Month,
    Channel,
    COUNT(DISTINCT Lead_Id) AS Lead,
    0 AS Sale,
    0 AS Revenue
  FROM (
    SELECT
      DATE_TRUNC(DATE(Lead_Date), MONTH) AS Month,

      CASE
        WHEN TRIM(LOWER(Marketing_Source)) = 'gupshup' THEN 'WhatsApp'
        WHEN TRIM(LOWER(Marketing_Source)) IN ('whatsapp','whtsapp')
          AND TRIM(LOWER(Marketing_Source)) != 'web-whatsapp'
          AND NOT (
            TRIM(LOWER(Marketing_Source)) = 'whatsapp'
            AND TRIM(LOWER(Marketing_Medium)) = 'whatsapp'
          ) THEN 'WhatsApp'
        WHEN TRIM(LOWER(Marketing_Source)) IN ('email','emailer','newsletter')
          OR TRIM(LOWER(Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'
        WHEN TRIM(LOWER(Marketing_Source)) LIKE '%rcs%'
          OR TRIM(LOWER(Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'
        WHEN TRIM(LOWER(Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
      END AS Channel,

      Lead_Id

    FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_internal`
    WHERE Lead_Date IS NOT NULL
  )
  WHERE Channel IN ('WhatsApp','Email','RCS','Push Notification')
  GROUP BY 1,2
),

-- =========================
-- 2️⃣ CRM SALES (FINAL - VERIFIED)
-- =========================
sales_kpi AS (
  SELECT
    Month,
    Channel,
    0 AS Lead,
    COUNT(DISTINCT invoice_id) AS Sale,
    SUM(Revenue) AS Revenue
  FROM (
    SELECT
      DATE_TRUNC(DATE(Invoice_Date), MONTH) AS Month,

      CASE
        WHEN TRIM(LOWER(Marketing_Source)) = 'gupshup' THEN 'WhatsApp'
        WHEN TRIM(LOWER(Marketing_Source)) IN ('whatsapp','whtsapp')
          AND TRIM(LOWER(Marketing_Source)) != 'web-whatsapp'
          AND NOT (
            TRIM(LOWER(Marketing_Source)) = 'whatsapp'
            AND TRIM(LOWER(Marketing_Medium)) = 'whatsapp'
          ) THEN 'WhatsApp'
        WHEN TRIM(LOWER(Marketing_Source)) IN ('email','emailer','newsletter')
          OR TRIM(LOWER(Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'
        WHEN TRIM(LOWER(Marketing_Source)) LIKE '%rcs%'
          OR TRIM(LOWER(Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'
        WHEN TRIM(LOWER(Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
      END AS Channel,

      CONCAT(Invoice_number,'_',IFNULL(Invoice_model_number,'NA')) AS invoice_id,
      Invoice_billing_amount AS Revenue

    FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal`
    WHERE Invoice_Date IS NOT NULL
  )
  WHERE Channel IN ('WhatsApp','Email','RCS','Push Notification')
  GROUP BY 1,2
),

-- =========================
-- 3️⃣ CRM FINAL (UNION - NO JOIN)
-- =========================
crm_final AS (
  SELECT * FROM lead_kpi
  UNION ALL
  SELECT * FROM sales_kpi
),

crm_agg AS (
  SELECT
    Month,
    Channel,
    SUM(Lead) AS Lead,
    SUM(Sale) AS Sale,
    SUM(Revenue) AS Revenue
  FROM crm_final
  GROUP BY 1,2
),

-- =========================
-- 4️⃣ CAMPAIGN STATS
-- =========================
campaign_base AS (
  SELECT
    DATE_TRUNC(DATE(Sent_Date_clean), MONTH) AS Month,

    CASE
      WHEN LOWER(Channel) LIKE '%gupshup%' OR LOWER(Channel) LIKE '%whatsapp%' THEN 'WhatsApp'
      WHEN LOWER(Channel) LIKE '%email%' THEN 'Email'
      WHEN LOWER(Channel) LIKE '%rcs%' THEN 'RCS'
      WHEN LOWER(Channel) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,

    SUM(Sent) AS Sent,
    SUM(Delivered) AS Delivered,
    SUM(Open_Count) AS Opened,
    SUM(Click_Count) AS Clicked,
    SUM(Cost) AS Cost

  FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`
  GROUP BY 1,2
)

-- =========================
-- FINAL OUTPUT
-- =========================
SELECT
  c.Month,
  FORMAT_DATE("%b'%y", c.Month) AS Month_Label,
  c.Channel,

  -- Campaign
  c.Sent,
  c.Delivered,
  c.Opened,
  c.Clicked,
  c.Cost,

  -- CRM (CURRENT ONLY - CORRECT)
  f.Lead,
  f.Sale,
  f.Revenue,

  -- KPIs
  SAFE_DIVIDE(f.Lead, c.Clicked) AS Click_to_Lead_pct,
  SAFE_DIVIDE(f.Sale, f.Lead) AS Lead_to_Sale_pct,
  SAFE_DIVIDE(f.Sale, c.Clicked) AS Click_to_Sale_pct,

  SAFE_DIVIDE(c.Cost, f.Lead) AS CPL,
  SAFE_DIVIDE(c.Cost, f.Sale) AS CPS,
  SAFE_DIVIDE(f.Revenue, f.Sale) AS AOV,
  SAFE_DIVIDE(f.Revenue, c.Cost) AS ROAS,

  'Current' AS Stage

FROM crm_agg f
LEFT JOIN campaign_base c
  ON f.Month = c.Month
  AND f.Channel = c.Channel;

-- =================================================================================================================================================================
-- DASHBOARD 2
-- =================================================================================================================================================================


CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard2_monthly` AS

-- =====================================================
-- 1️⃣ BASE CAMPAIGN (DAY LEVEL)
-- =====================================================
WITH base_campaign AS (

SELECT
  DATE(Sent_Date) AS Sent_Date,
  DATE_TRUNC(DATE(Sent_Date), MONTH) AS Campaign_Month,
  TRIM(LOWER(utm_key)) AS utm_key,
  Channel,

  SUM(Sent) AS Sent,
  SUM(Delivered) AS Delivered,
  SUM(Open_Count) AS Opened,      -- ✅ ADDED
  SUM(Click_Count) AS Clicks

FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`

WHERE Sent > 0

GROUP BY 1,2,3,4
),

-- =====================================================
-- 2️⃣ FIRST CAMPAIGN DATE
-- =====================================================
first_campaign AS (
  SELECT MIN(Sent_Date) AS first_date
  FROM base_campaign
),

-- =====================================================
-- 3️⃣ LEAD SPLIT (SAME AS DASHBOARD 1)
-- =====================================================
lead_split AS (

SELECT
  b.Sent_Date,
  b.Channel,

  COUNT(DISTINCT l.Lead_Id) AS Leads,

  CASE
    WHEN DATE_TRUNC(l.Lead_Date, MONTH) = b.Campaign_Month THEN 'Current'
    WHEN DATE_TRUNC(l.Lead_Date, MONTH) > b.Campaign_Month THEN 'Rolling'
  END AS Type

FROM base_campaign b
LEFT JOIN `whatsappanalysis-487206.Best_day_time.Lead_Data_internal` l
ON b.utm_key = TRIM(LOWER(l.utm_key))

WHERE l.Lead_Date IS NOT NULL

GROUP BY 1,2,Type
),

lead_final AS (

SELECT
  Sent_Date,
  Channel,

  SUM(CASE WHEN Type='Current' THEN Leads ELSE 0 END) AS Current_Leads,
  SUM(CASE WHEN Type='Rolling' THEN Leads ELSE 0 END) AS Rolling_Leads

FROM lead_split
GROUP BY 1,2
),

-- =====================================================
-- 4️⃣ SALES SPLIT
-- =====================================================
sales_split AS (

SELECT
  b.Sent_Date,
  b.Channel,

  COUNT(DISTINCT CONCAT(i.Invoice_number,'_',IFNULL(i.Invoice_model_number,'NA'))) AS Sales,

  CASE
    WHEN DATE_TRUNC(i.Invoice_Date, MONTH) = b.Campaign_Month THEN 'Current'
    WHEN DATE_TRUNC(i.Invoice_Date, MONTH) > b.Campaign_Month THEN 'Rolling'
  END AS Type

FROM base_campaign b
LEFT JOIN `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal` i
ON b.utm_key = TRIM(LOWER(i.utm_key))

WHERE i.Invoice_Date IS NOT NULL

GROUP BY 1,2,Type
),

sales_final AS (

SELECT
  Sent_Date,
  Channel,

  SUM(CASE WHEN Type='Current' THEN Sales ELSE 0 END) AS Current_Sales,
  SUM(CASE WHEN Type='Rolling' THEN Sales ELSE 0 END) AS Rolling_Sales

FROM sales_split
GROUP BY 1,2
),

-- =====================================================
-- 5️⃣ ENGAGEMENT
-- =====================================================
engagement AS (

SELECT
  Sent_Date,
  Channel,

  SUM(Sent) AS Sent,
  SUM(Delivered) AS Delivered,
  SUM(Opened) AS Opened,      -- ✅ ADDED
  SUM(Clicks) AS Clicks

FROM base_campaign
GROUP BY 1,2
)

-- =====================================================
-- 6️⃣ FINAL OUTPUT
-- =====================================================
SELECT
  e.Sent_Date,
  FORMAT_DATE("%b'%y", e.Sent_Date) AS Month_Label,
  e.Channel,

  -- Engagement
  e.Sent,
  e.Delivered,
  e.Opened,     -- ✅ NOW AVAILABLE
  e.Clicks,

  -- Funnel
  IFNULL(lf.Current_Leads, 0) AS Current_Leads,
  IFNULL(lf.Rolling_Leads, 0) AS Rolling_Leads,
  IFNULL(lf.Current_Leads, 0) + IFNULL(lf.Rolling_Leads, 0) AS Total_Leads,

  IFNULL(sf.Current_Sales, 0) AS Current_Sales,
  IFNULL(sf.Rolling_Sales, 0) AS Rolling_Sales,
  IFNULL(sf.Current_Sales, 0) + IFNULL(sf.Rolling_Sales, 0) AS Total_Sales

FROM engagement e

LEFT JOIN lead_final lf
ON e.Sent_Date = lf.Sent_Date AND e.Channel = lf.Channel

LEFT JOIN sales_final sf
ON e.Sent_Date = sf.Sent_Date AND e.Channel = sf.Channel

WHERE e.Sent_Date >= (SELECT first_date FROM first_campaign)
;




-- =================================================================================================================================================================
-- DASHBOARD 3
-- =================================================================================================================================================================

CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard3_monthly_aging` AS

WITH campaign_base AS (
  SELECT
    TRIM(LOWER(utm_key)) AS utm_key,
    DATE_TRUNC(DATE(Sent_Date_clean), MONTH) AS Campaign_Month,
    MIN(DATE(Sent_Date_clean)) AS Sent_Date
  FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`
  WHERE utm_key IS NOT NULL
  GROUP BY 1,2
),

-- =========================
-- LEAD BASE (CRM ONLY)
-- =========================
lead_base AS (
  SELECT
    DATE_TRUNC(DATE(l.Lead_Date), MONTH) AS Month,

    CASE
      WHEN TRIM(LOWER(l.Marketing_Source)) = 'gupshup' THEN 'WhatsApp'
      WHEN TRIM(LOWER(l.Marketing_Source)) IN ('whatsapp','whtsapp')
        AND TRIM(LOWER(l.Marketing_Source)) != 'web-whatsapp'
        AND NOT (
          TRIM(LOWER(l.Marketing_Source)) = 'whatsapp'
          AND TRIM(LOWER(l.Marketing_Medium)) = 'whatsapp'
        ) THEN 'WhatsApp'
      WHEN TRIM(LOWER(l.Marketing_Source)) IN ('email','emailer','newsletter')
        OR TRIM(LOWER(l.Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'
      WHEN TRIM(LOWER(l.Marketing_Source)) LIKE '%rcs%'
        OR TRIM(LOWER(l.Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'
      WHEN TRIM(LOWER(l.Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,

    TRIM(LOWER(l.utm_key)) AS utm_key,
    DATE(l.Lead_Date) AS Lead_Date,
    l.Lead_Id

  FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_internal` l
  WHERE l.Lead_Date IS NOT NULL
),

-- =========================
-- INVOICE BASE (CRM ONLY)
-- =========================
invoice_base AS (
  SELECT
    DATE_TRUNC(DATE(i.Invoice_Date), MONTH) AS Month,

    CASE
      WHEN TRIM(LOWER(i.Marketing_Source)) = 'gupshup' THEN 'WhatsApp'
      WHEN TRIM(LOWER(i.Marketing_Source)) IN ('whatsapp','whtsapp')
        AND TRIM(LOWER(i.Marketing_Source)) != 'web-whatsapp'
        AND NOT (
          TRIM(LOWER(i.Marketing_Source)) = 'whatsapp'
          AND TRIM(LOWER(i.Marketing_Medium)) = 'whatsapp'
        ) THEN 'WhatsApp'
      WHEN TRIM(LOWER(i.Marketing_Source)) IN ('email','emailer','newsletter')
        OR TRIM(LOWER(i.Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'
      WHEN TRIM(LOWER(i.Marketing_Source)) LIKE '%rcs%'
        OR TRIM(LOWER(i.Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'
      WHEN TRIM(LOWER(i.Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,

    TRIM(LOWER(i.utm_key)) AS utm_key,
    DATE(i.Invoice_Date) AS Invoice_Date,
    CONCAT(i.Invoice_number,'_',IFNULL(i.Invoice_model_number,'NA')) AS invoice_id,
    i.Invoice_billing_amount AS Revenue

  FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal` i
  WHERE i.Invoice_Date IS NOT NULL
),

-- =========================
-- LEAD AGING
-- =========================
lead_aging AS (
  SELECT
    l.Month,
    l.Channel,

    CASE
      WHEN c.utm_key IS NULL THEN 'Old Campaign'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) < 0 THEN 'Old Campaign'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 0 AND 1 THEN 'D0-D1'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 2 AND 7 THEN 'D2-D7'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 8 AND 15 THEN 'D8-D15'
      WHEN DATE_DIFF(l.Lead_Date, c.Sent_Date, DAY) BETWEEN 16 AND 30 THEN 'D16-D30'
      ELSE 'D30+'
    END AS Aging_Bucket,

    COUNT(DISTINCT l.Lead_Id) AS Lead

  FROM lead_base l
  LEFT JOIN campaign_base c
    ON l.utm_key = c.utm_key
    AND l.Month = c.Campaign_Month

  WHERE l.Channel IS NOT NULL

  GROUP BY 1,2,3
),

-- =========================
-- INVOICE AGING
-- =========================
invoice_aging AS (
  SELECT
    i.Month,
    i.Channel,

    CASE
      WHEN c.utm_key IS NULL THEN 'Old Campaign'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) < 0 THEN 'Old Campaign'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 0 AND 1 THEN 'D0-D1'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 2 AND 7 THEN 'D2-D7'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 8 AND 15 THEN 'D8-D15'
      WHEN DATE_DIFF(i.Invoice_Date, c.Sent_Date, DAY) BETWEEN 16 AND 30 THEN 'D16-D30'
      ELSE 'D30+'
    END AS Aging_Bucket,

    COUNT(DISTINCT i.invoice_id) AS Sale,
    SUM(i.Revenue) AS Revenue

  FROM invoice_base i
  LEFT JOIN campaign_base c
    ON i.utm_key = c.utm_key
    AND i.Month = c.Campaign_Month

  WHERE i.Channel IS NOT NULL

  GROUP BY 1,2,3
),

-- =========================
-- FINAL MERGE
-- =========================
final_union AS (
  SELECT Month, Channel, Aging_Bucket, Lead, 0 AS Sale, 0 AS Revenue FROM lead_aging
  UNION ALL
  SELECT Month, Channel, Aging_Bucket, 0, Sale, Revenue FROM invoice_aging
)

SELECT
  Month,
  FORMAT_DATE("%b'%y", Month) AS Month_Label,
  Channel,
  Aging_Bucket,

  CASE
    WHEN Aging_Bucket = 'Old Campaign' THEN 0
    WHEN Aging_Bucket = 'D0-D1' THEN 1
    WHEN Aging_Bucket = 'D2-D7' THEN 2
    WHEN Aging_Bucket = 'D8-D15' THEN 3
    WHEN Aging_Bucket = 'D16-D30' THEN 4
    WHEN Aging_Bucket = 'D30+' THEN 5
  END AS Aging_Order,

  SUM(Lead) AS Lead,
  SUM(Sale) AS Sale,
  SUM(Revenue) AS Revenue,

  SAFE_DIVIDE(SUM(Sale), SUM(Lead)) AS Conversion_Rate,
  SAFE_DIVIDE(SUM(Revenue), SUM(Sale)) AS AOV

FROM final_union

GROUP BY Month, Month_Label, Channel, Aging_Bucket, Aging_Order;


-- =================================================================================================================================================================
-- DASHBOARD 4
-- =================================================================================================================================================================



CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard4_monthly_campaign` AS

-- =========================
-- 1️⃣ CAMPAIGN BASE (FOR NAME + TYPE)
-- =========================
WITH campaign_base AS (
  SELECT
    TRIM(LOWER(utm_key)) AS utm_key,
    DATE_TRUNC(DATE(Sent_Date_clean), MONTH) AS Campaign_Month,
    ANY_VALUE(Master_Campaign_Name) AS Master_Campaign_Name
  FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`
  GROUP BY 1,2
),

-- =========================
-- 2️⃣ LEAD BASE (CRM ONLY + CHANNEL + TYPE)
-- =========================
lead_base AS (
  SELECT
    DATE_TRUNC(DATE(l.Lead_Date), MONTH) AS Month,

    CASE
      WHEN TRIM(LOWER(l.Marketing_Source)) = 'gupshup' THEN 'WhatsApp'
      WHEN TRIM(LOWER(l.Marketing_Source)) IN ('whatsapp','whtsapp')
        AND TRIM(LOWER(l.Marketing_Source)) != 'web-whatsapp'
        AND NOT (
          TRIM(LOWER(l.Marketing_Source)) = 'whatsapp'
          AND TRIM(LOWER(l.Marketing_Medium)) = 'whatsapp'
        ) THEN 'WhatsApp'
      WHEN TRIM(LOWER(l.Marketing_Source)) IN ('email','emailer','newsletter')
        OR TRIM(LOWER(l.Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'
      WHEN TRIM(LOWER(l.Marketing_Source)) LIKE '%rcs%'
        OR TRIM(LOWER(l.Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'
      WHEN TRIM(LOWER(l.Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,

    COALESCE(c.Master_Campaign_Name, l.utm_key) AS Campaign_Name,

    CASE
      WHEN DATE_TRUNC(DATE(l.Lead_Date), MONTH) = c.Campaign_Month THEN 'Current Campaign'
      ELSE 'Old Campaign'
    END AS Campaign_Type,

    l.Lead_Id,
    l.Lead_Status

  FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_internal` l

  LEFT JOIN campaign_base c
    ON TRIM(LOWER(l.utm_key)) = c.utm_key
    AND DATE_TRUNC(DATE(l.Lead_Date), MONTH) = c.Campaign_Month

  WHERE l.Lead_Date IS NOT NULL
),

-- =========================
-- 3️⃣ SALES BASE (CRM ONLY + CHANNEL + TYPE)
-- =========================
invoice_base AS (
  SELECT
    DATE_TRUNC(DATE(i.Invoice_Date), MONTH) AS Month,

    CASE
      WHEN TRIM(LOWER(i.Marketing_Source)) = 'gupshup' THEN 'WhatsApp'
      WHEN TRIM(LOWER(i.Marketing_Source)) IN ('whatsapp','whtsapp')
        AND TRIM(LOWER(i.Marketing_Source)) != 'web-whatsapp'
        AND NOT (
          TRIM(LOWER(i.Marketing_Source)) = 'whatsapp'
          AND TRIM(LOWER(i.Marketing_Medium)) = 'whatsapp'
        ) THEN 'WhatsApp'
      WHEN TRIM(LOWER(i.Marketing_Source)) IN ('email','emailer','newsletter')
        OR TRIM(LOWER(i.Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'
      WHEN TRIM(LOWER(i.Marketing_Source)) LIKE '%rcs%'
        OR TRIM(LOWER(i.Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'
      WHEN TRIM(LOWER(i.Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,

    COALESCE(c.Master_Campaign_Name, i.utm_key) AS Campaign_Name,

    CASE
      WHEN DATE_TRUNC(DATE(i.Invoice_Date), MONTH) = c.Campaign_Month THEN 'Current Campaign'
      ELSE 'Old Campaign'
    END AS Campaign_Type,

    CONCAT(i.Invoice_number,'_',IFNULL(i.Invoice_model_number,'NA')) AS invoice_id,
    i.Invoice_billing_amount AS Revenue

  FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal` i

  LEFT JOIN campaign_base c
    ON TRIM(LOWER(i.utm_key)) = c.utm_key
    AND DATE_TRUNC(DATE(i.Invoice_Date), MONTH) = c.Campaign_Month

  WHERE i.Invoice_Date IS NOT NULL
),

-- =========================
-- 4️⃣ LEAD KPI
-- =========================
lead_kpi AS (
  SELECT
    Month, Channel, Campaign_Name, Campaign_Type,
    COUNT(DISTINCT Lead_Id) AS Total_Lead,
    COUNT(DISTINCT CASE WHEN Lead_Status = 'Qualified' THEN Lead_Id END) AS Qualified_Lead,
    COUNT(DISTINCT CASE WHEN Lead_Status = 'Unqualified' THEN Lead_Id END) AS Unqualified_Lead
  FROM lead_base
  WHERE Channel IS NOT NULL
  GROUP BY 1,2,3,4
),

-- =========================
-- 5️⃣ SALES KPI
-- =========================
sales_kpi AS (
  SELECT
    Month, Channel, Campaign_Name, Campaign_Type,
    COUNT(DISTINCT invoice_id) AS Total_Sale,
    SUM(Revenue) AS Revenue
  FROM invoice_base
  WHERE Channel IS NOT NULL
  GROUP BY 1,2,3,4
),

-- =========================
-- 6️⃣ FINAL MERGE
-- =========================
final_union AS (
  SELECT Month, Channel, Campaign_Name, Campaign_Type, Total_Lead, Qualified_Lead, Unqualified_Lead, 0 AS Total_Sale, 0 AS Revenue FROM lead_kpi
  UNION ALL
  SELECT Month, Channel, Campaign_Name, Campaign_Type, 0, 0, 0, Total_Sale, Revenue FROM sales_kpi
)

-- =========================
-- 7️⃣ FINAL OUTPUT (TOTAL % FIXED)
-- =========================
SELECT
  Month,
  FORMAT_DATE("%b'%y", Month) AS Month_Label,
  Channel,
  Campaign_Name AS Master_Campaign_Name,
  Campaign_Type,

  SUM(Total_Lead) AS Total_Lead,
  SUM(Total_Sale) AS Total_Sale,
  SUM(Revenue) AS Revenue,

  SUM(Total_Lead) - SUM(Qualified_Lead) - SUM(Unqualified_Lead) AS Open_Lead,
  SUM(Qualified_Lead) AS Qualified_Lead,
  SUM(Unqualified_Lead) AS Unqualified_Lead,

  SAFE_DIVIDE(SUM(Total_Lead) - SUM(Qualified_Lead) - SUM(Unqualified_Lead), SUM(Total_Lead)) AS Open_Percentage,
  SAFE_DIVIDE(SUM(Qualified_Lead), SUM(Total_Lead)) AS Qualified_Percentage,
  SAFE_DIVIDE(SUM(Unqualified_Lead), SUM(Total_Lead)) AS Unqualified_Percentage

FROM final_union

WHERE Month >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH)

GROUP BY Month, Month_Label, Channel, Master_Campaign_Name, Campaign_Type;


-- =================================================================================================================================================================
-- DASHBOARD 5
-- =================================================================================================================================================================



CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard5_monthly_brand_contribution` AS

-- =========================
-- 1️⃣ LEAD BASE (CRM ONLY)
-- =========================
WITH lead_base AS (
  SELECT
    DATE_TRUNC(DATE(Lead_Date), MONTH) AS Month,

    -- CRM CHANNEL LOGIC
    CASE
      WHEN TRIM(LOWER(Marketing_Source)) = 'gupshup' THEN 'WhatsApp'

      WHEN TRIM(LOWER(Marketing_Source)) IN ('whatsapp','whtsapp')
        AND TRIM(LOWER(Marketing_Source)) != 'web-whatsapp'
        AND NOT (
          TRIM(LOWER(Marketing_Source)) = 'whatsapp'
          AND TRIM(LOWER(Marketing_Medium)) = 'whatsapp'
        ) THEN 'WhatsApp'

      WHEN TRIM(LOWER(Marketing_Source)) IN ('email','emailer','newsletter')
        OR TRIM(LOWER(Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'

      WHEN TRIM(LOWER(Marketing_Source)) LIKE '%rcs%'
        OR TRIM(LOWER(Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'

      WHEN TRIM(LOWER(Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,

    -- ✅ BRAND NORMALIZATION (FIX DUPLICATES)
    TRIM(LOWER(Lead_Brand)) AS Brand,

    Lead_Id,
    Lead_Status

  FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_internal`
  WHERE Lead_Date IS NOT NULL
),

-- =========================
-- 2️⃣ SALES BASE (CRM ONLY)
-- =========================
sales_base AS (
  SELECT
    DATE_TRUNC(DATE(Invoice_Date), MONTH) AS Month,

    -- CRM CHANNEL LOGIC
    CASE
      WHEN TRIM(LOWER(Marketing_Source)) = 'gupshup' THEN 'WhatsApp'

      WHEN TRIM(LOWER(Marketing_Source)) IN ('whatsapp','whtsapp')
        AND TRIM(LOWER(Marketing_Source)) != 'web-whatsapp'
        AND NOT (
          TRIM(LOWER(Marketing_Source)) = 'whatsapp'
          AND TRIM(LOWER(Marketing_Medium)) = 'whatsapp'
        ) THEN 'WhatsApp'

      WHEN TRIM(LOWER(Marketing_Source)) IN ('email','emailer','newsletter')
        OR TRIM(LOWER(Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'

      WHEN TRIM(LOWER(Marketing_Source)) LIKE '%rcs%'
        OR TRIM(LOWER(Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'

      WHEN TRIM(LOWER(Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,

    -- ✅ BRAND NORMALIZATION (FIX DUPLICATES)
    TRIM(LOWER(Invoice_brand_name)) AS Brand,

    CONCAT(Invoice_number,'_',IFNULL(Invoice_model_number,'NA')) AS invoice_id,
    Invoice_billing_amount AS Revenue

  FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal`
  WHERE Invoice_Date IS NOT NULL
),

-- =========================
-- 3️⃣ LEAD KPI
-- =========================
lead_kpi AS (
  SELECT
    Month,
    Channel,
    Brand,

    COUNT(DISTINCT Lead_Id) AS Total_Lead,
    COUNT(DISTINCT CASE WHEN Lead_Status = 'Qualified' THEN Lead_Id END) AS Qualified_Lead,
    COUNT(DISTINCT CASE WHEN Lead_Status = 'Unqualified' THEN Lead_Id END) AS Unqualified_Lead,

    0 AS Total_Sale,
    0 AS Revenue,

    1 AS has_lead,
    0 AS has_sale

  FROM lead_base
  WHERE Channel IS NOT NULL
  GROUP BY 1,2,3
),

-- =========================
-- 4️⃣ SALES KPI
-- =========================
sales_kpi AS (
  SELECT
    Month,
    Channel,
    Brand,

    0 AS Total_Lead,
    0 AS Qualified_Lead,
    0 AS Unqualified_Lead,

    COUNT(DISTINCT invoice_id) AS Total_Sale,
    SUM(Revenue) AS Revenue,

    0 AS has_lead,
    1 AS has_sale

  FROM sales_base
  WHERE Channel IS NOT NULL
  GROUP BY 1,2,3
),

-- =========================
-- 5️⃣ FINAL UNION (NO JOIN 🚨)
-- =========================
final_union AS (
  SELECT * FROM lead_kpi
  UNION ALL
  SELECT * FROM sales_kpi
)

-- =========================
-- 6️⃣ FINAL OUTPUT
-- =========================
SELECT
  Month,
  FORMAT_DATE("%b'%y", Month) AS Month_Label,
  Channel,

  -- Optional: Clean display (Rolex instead of rolex)
  INITCAP(Brand) AS Brand,

  CASE
    WHEN SUM(has_lead) > 0 AND SUM(has_sale) > 0 THEN 'Current'
    WHEN SUM(has_lead) > 0 THEN 'Lead Only'
    WHEN SUM(has_sale) > 0 THEN 'Sale Only'
  END AS Brand_Type,

  SUM(Total_Lead) AS Total_Lead,
  SUM(Total_Sale) AS Total_Sale,
  SUM(Revenue) AS Revenue,

  SUM(Total_Lead) - SUM(Qualified_Lead) - SUM(Unqualified_Lead) AS Open_Lead,
  SUM(Qualified_Lead) AS Qualified_Lead,
  SUM(Unqualified_Lead) AS Unqualified_Lead

FROM final_union

WHERE Month >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH), MONTH)

GROUP BY Month, Month_Label, Channel, Brand;


-- =================================================================================================================================================================
-- DASHBOARD 6
-- =================================================================================================================================================================



CREATE OR REPLACE TABLE `whatsappanalysis-487206.Best_day_time.dashboard6_monthly_financial_summary` AS

WITH sales_base AS (
  SELECT
    DATE_TRUNC(Invoice_Date, MONTH) AS Month,
    CASE
      WHEN TRIM(LOWER(Marketing_Source)) = 'gupshup' THEN 'WhatsApp'
      WHEN TRIM(LOWER(Marketing_Source)) IN ('whatsapp','whtsapp')
        AND TRIM(LOWER(Marketing_Source)) != 'web-whatsapp'
        AND NOT (
          TRIM(LOWER(Marketing_Source)) = 'whatsapp'
          AND TRIM(LOWER(Marketing_Medium)) = 'whatsapp'
        ) THEN 'WhatsApp'
      WHEN TRIM(LOWER(Marketing_Source)) IN ('email','emailer','newsletter')
        OR TRIM(LOWER(Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'
      WHEN TRIM(LOWER(Marketing_Source)) LIKE '%rcs%'
        OR TRIM(LOWER(Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'
      WHEN TRIM(LOWER(Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,
    conversion_type_new,
    COUNT(DISTINCT CONCAT(Invoice_number,'_',IFNULL(Invoice_model_number,'NA'))) AS Sale,
    SUM(Invoice_billing_amount) AS Revenue
  FROM `whatsappanalysis-487206.Best_day_time.Invoice_Data_internal`
  GROUP BY 1,2,3
),

sales_split AS (
  SELECT
    Month,
    Channel,
    SUM(CASE WHEN conversion_type_new = 'Current' THEN Sale ELSE 0 END) AS Current_Sale,
    SUM(CASE WHEN conversion_type_new = 'Rolling' THEN Sale ELSE 0 END) AS Rolling_Sale,
    SUM(CASE WHEN conversion_type_new = 'Current' THEN Revenue ELSE 0 END) AS Current_Revenue,
    SUM(CASE WHEN conversion_type_new = 'Rolling' THEN Revenue ELSE 0 END) AS Rolling_Revenue,
    SUM(Revenue) AS Total_Revenue
  FROM sales_base
  WHERE Channel IN ('WhatsApp','Email','RCS','Push Notification')
  GROUP BY 1,2
),

lead_base AS (
  SELECT
    DATE_TRUNC(Lead_Date, MONTH) AS Month,
    CASE
      WHEN TRIM(LOWER(Marketing_Source)) = 'gupshup' THEN 'WhatsApp'
      WHEN TRIM(LOWER(Marketing_Source)) IN ('whatsapp','whtsapp')
        AND TRIM(LOWER(Marketing_Source)) != 'web-whatsapp'
        AND NOT (
          TRIM(LOWER(Marketing_Source)) = 'whatsapp'
          AND TRIM(LOWER(Marketing_Medium)) = 'whatsapp'
        ) THEN 'WhatsApp'
      WHEN TRIM(LOWER(Marketing_Source)) IN ('email','emailer','newsletter')
        OR TRIM(LOWER(Marketing_Medium)) IN ('email','emailer','newsletter') THEN 'Email'
      WHEN TRIM(LOWER(Marketing_Source)) LIKE '%rcs%'
        OR TRIM(LOWER(Marketing_Medium)) LIKE '%rcs%' THEN 'RCS'
      WHEN TRIM(LOWER(Marketing_Source)) LIKE '%push%' THEN 'Push Notification'
    END AS Channel,
    COUNT(DISTINCT Lead_Id) AS Lead
  FROM `whatsappanalysis-487206.Best_day_time.Lead_Data_internal`
  GROUP BY 1,2
),

cost_base AS (
  SELECT
    DATE_TRUNC(DATE(Sent_Date_clean), MONTH) AS Month,
    SUM(Cost) AS Total_Cost
  FROM `whatsappanalysis-487206.Best_day_time.campaign_performance_internal`
  GROUP BY 1
),

month_total_rev AS (
  SELECT Month, SUM(Total_Revenue) AS Month_Revenue
  FROM sales_split
  GROUP BY 1
),

base AS (
  SELECT
    s.Month,
    s.Channel,
    IFNULL(l.Lead,0) AS Lead,
    s.Current_Sale,
    s.Rolling_Sale,
    s.Current_Revenue,
    s.Rolling_Revenue,
    SAFE_DIVIDE(s.Total_Revenue, m.Month_Revenue) * c.Total_Cost AS Cost
  FROM sales_split s
  LEFT JOIN lead_base l ON s.Month = l.Month AND s.Channel = l.Channel
  LEFT JOIN cost_base c ON s.Month = c.Month
  LEFT JOIN month_total_rev m ON s.Month = m.Month
)

SELECT *
FROM (

SELECT 
  Month,
  Channel,
  1 AS metric_order,
  'Lead' AS Metric,
  Lead AS Current_Value,
  NULL AS Rolling_Value,
  Lead AS Total_Value
FROM base

UNION ALL

SELECT 
  Month,
  Channel,
  2,
  'Cost',
  Cost,
  NULL,
  Cost
FROM base

UNION ALL

SELECT 
  Month,
  Channel,
  3,
  'Sale',
  Current_Sale,
  Rolling_Sale,
  Current_Sale + Rolling_Sale
FROM base

UNION ALL

SELECT 
  Month,
  Channel,
  4,
  'Revenue',
  Current_Revenue,
  Rolling_Revenue,
  Current_Revenue + Rolling_Revenue
FROM base

)
ORDER BY Month, Channel, metric_order;