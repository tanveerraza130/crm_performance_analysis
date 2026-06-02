CREATE OR REPLACE VIEW `whatsappanalysis-487206.Best_day_time.dashboard1_monthly_funnel` AS

WITH base AS (
  SELECT
    Month,
    FORMAT_DATE("%b'%y", Month) AS Month_Label,
    Channel,

    -- 🔥 FIX: AGGREGATE FIRST
    SUM(Sent) AS Sent,
    SUM(Delivered) AS Delivered,
    SUM(Opened) AS Opened,
    SUM(Clicked) AS Clicked,
    SUM(Lead) AS Lead,
    SUM(Sale) AS Sale

  FROM `whatsappanalysis-487206.Best_day_time.dashboard1_monthly`
  GROUP BY Month, Month_Label, Channel
)

SELECT Month, Month_Label, Channel, 'Sent' AS Stage, Sent AS Value, 1 AS Stage_Order FROM base
UNION ALL
SELECT Month, Month_Label, Channel, 'Delivered', Delivered, 2 FROM base
UNION ALL
SELECT Month, Month_Label, Channel, 'Opened', Opened, 3 FROM base
UNION ALL
SELECT Month, Month_Label, Channel, 'Clicked', Clicked, 4 FROM base
UNION ALL
SELECT Month, Month_Label, Channel, 'Lead', Lead, 5 FROM base
UNION ALL
SELECT Month, Month_Label, Channel, 'Sale', Sale, 6 FROM base;