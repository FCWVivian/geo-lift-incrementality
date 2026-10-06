-- GA4 Google Merchandise Store public sample (2020-11-01 ~ 2021-01-31)
-- Output: one row per US state x day  ->  geo panel for geo lift analysis
WITH events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS date,
    geo.region AS state,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE geo.country = 'United States'
    AND geo.region NOT IN ('(not set)', '')
)
SELECT
  date,
  state,
  COUNT(DISTINCT CONCAT(user_pseudo_id, CAST(session_id AS STRING))) AS sessions,
  COUNT(DISTINCT user_pseudo_id)                                     AS users,
  COUNTIF(event_name = 'purchase')                                   AS purchases,
  ROUND(SUM(IF(event_name = 'purchase', revenue, 0)), 2)             AS revenue
FROM events
GROUP BY date, state
ORDER BY state, date
