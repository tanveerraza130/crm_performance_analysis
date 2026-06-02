CREATE OR REPLACE VIEW `whatsappanalysis-487206.Best_day_time.dashboard_funnel` AS

SELECT
  Month,
  Business,
  Channel,
  Master_Campaign_Name,
  Sent_Date,
  Stage,
  Value,
  Stage_Order
FROM (
  SELECT
    Month,
    Business,
    Channel,
    Master_Campaign_Name,
    Sent_Date,
    Sent,
    Delivered,
    Opened,
    Clicked,
    Lead,
    Sale
  FROM `whatsappanalysis-487206.Best_day_time.dashboard1_anchor`
),
UNNEST([
  STRUCT('Sent' AS Stage, Sent AS Value, 1 AS Stage_Order),
  STRUCT('Delivered', Delivered, 2),
  STRUCT('Opened', Opened, 3),
  STRUCT('Clicked', Clicked, 4),
  STRUCT('Lead', Lead, 5),
  STRUCT('Sale', Sale, 6)
]);