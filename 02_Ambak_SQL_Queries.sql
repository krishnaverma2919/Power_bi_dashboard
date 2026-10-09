/* =====================================================================
   Ambak Analyst Assignment - SQL Queries
   Dialect : PostgreSQL  (each sheet treated as a table of the same name)
   Notes   : - leads has 76 exact duplicate rows -> lead_id is de-duplicated
               everywhere (COUNT(DISTINCT lead_id) / DISTINCT subquery).
             - "Outbound" = call_type LIKE 'outbound%'  (inbound excluded).
             - Calls on lead_ids that are not in leads are excluded (join to leads).
             - Connected call = call_duration_ms > 0.
             - Every day of September is shown, even when there were 0 calls
               (Sundays), by joining to a generated calendar.
   ===================================================================== */


/* ---------------------------------------------------------------------
   SQL 1 : For every day in Sep 2025 -> date, leads attempted (unique
           leads called), total outbound calls, connected calls
   --------------------------------------------------------------------- */
WITH days AS (
    SELECT d::date AS call_date
    FROM generate_series('2025-09-01'::date, '2025-09-30'::date, interval '1 day') AS g(d)
),
valid_leads AS (
    SELECT DISTINCT lead_id FROM leads
),
outbound_calls AS (
    SELECT DATE(c.dialled_at) AS call_date,
           c.lead_id,
           c.call_duration_ms
    FROM call_logs c
    JOIN valid_leads v ON v.lead_id = c.lead_id          -- drops orphan calls
    WHERE c.call_type LIKE 'outbound%'                   -- drops inbound
)
SELECT d.call_date                                                        AS date,
       COUNT(DISTINCT o.lead_id)                                          AS leads_attempted,
       COUNT(o.lead_id)                                                   AS total_outbound_calls,
       COALESCE(SUM(CASE WHEN o.call_duration_ms > 0 THEN 1 ELSE 0 END), 0) AS connected_calls
FROM days d
LEFT JOIN outbound_calls o ON o.call_date = d.call_date
GROUP BY d.call_date
ORDER BY d.call_date;


/* ---------------------------------------------------------------------
   SQL 2 : For every day in Sep 2025 -> number of agents who made
           MORE THAN 10 outbound calls that day
   --------------------------------------------------------------------- */
WITH days AS (
    SELECT d::date AS call_date
    FROM generate_series('2025-09-01'::date, '2025-09-30'::date, interval '1 day') AS g(d)
),
valid_leads AS (
    SELECT DISTINCT lead_id FROM leads
),
agent_day AS (
    SELECT DATE(c.dialled_at) AS call_date,
           c.agent_email,
           COUNT(*)           AS outbound_calls
    FROM call_logs c
    JOIN valid_leads v ON v.lead_id = c.lead_id
    WHERE c.call_type LIKE 'outbound%'
    GROUP BY DATE(c.dialled_at), c.agent_email
    HAVING COUNT(*) > 10
)
SELECT d.call_date                     AS date,
       COUNT(a.agent_email)            AS agents_with_more_than_10_calls
FROM days d
LEFT JOIN agent_day a ON a.call_date = d.call_date
GROUP BY d.call_date
ORDER BY d.call_date;


/* ---------------------------------------------------------------------
   SQL 3 : For each lead-created month and CD Bucket -> number of leads and
           how many of those leads got qualified / logged in / disbursed
           (cohort view: stage can happen in any later month)

SELECT TO_CHAR(created_at, 'YYYY-MM')                                        AS lead_created_month,
       cd_bucket,
       COUNT(DISTINCT lead_id)                                               AS leads,
       COUNT(DISTINCT CASE WHEN qualified_date IS NOT NULL THEN lead_id END) AS qualified_leads,
       COUNT(DISTINCT CASE WHEN login_date     IS NOT NULL THEN lead_id END) AS logged_in_leads,
       COUNT(DISTINCT CASE WHEN disbursal_date IS NOT NULL THEN lead_id END) AS disbursed_leads
FROM leads
GROUP BY TO_CHAR(created_at, 'YYYY-MM'), cd_bucket
ORDER BY lead_created_month, cd_bucket;
