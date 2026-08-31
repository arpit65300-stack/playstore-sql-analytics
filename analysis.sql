-- =========================================================
-- Google Play Store — SQL Analytics & A/B Testing
-- Author: Arpit Kumar
-- =========================================================
-- Run in order. Assumes googleplaystore.csv and
-- googleplaystore_user_reviews.csv are available locally.
-- =========================================================


-- =========================================================
-- 1. SETUP — create database and raw tables
-- =========================================================

CREATE DATABASE playstore_analysis;
-- \c playstore_analysis

CREATE TABLE apps (
    app_name TEXT,
    category TEXT,
    rating TEXT,
    reviews TEXT,
    size TEXT,
    installs TEXT,
    type TEXT,
    price TEXT,
    content_rating TEXT,
    genres TEXT,
    last_updated TEXT,
    current_ver TEXT,
    android_ver TEXT
);

CREATE TABLE user_reviews (
    app_name TEXT,
    translated_review TEXT,
    sentiment TEXT,
    sentiment_polarity NUMERIC,
    sentiment_subjectivity NUMERIC
);

-- Load raw CSVs as TEXT first (source file has an inconsistent
-- row — see cleaning note below), then clean/cast in SQL.
-- \encoding LATIN1
-- \copy apps FROM 'path/to/googleplaystore.csv' DELIMITER ',' CSV HEADER;
-- \copy user_reviews FROM 'path/to/googleplaystore_user_reviews.csv' DELIMITER ',' CSV HEADER;


-- =========================================================
-- 2. DATA CLEANING
-- =========================================================
-- Note: one row (Life Made WI-Fi Touchscreen Photo Frame) is
-- missing its category value in the source CSV, shifting every
-- later column over by one. Fixed by inserting "LIFESTYLE" back
-- into that row in the raw CSV before import.

CREATE TABLE apps_clean AS
SELECT
    app_name,
    category,
    NULLIF(rating, 'NaN')::NUMERIC AS rating,
    reviews::INTEGER AS reviews,
    CASE
        WHEN size LIKE '%M' THEN REPLACE(size, 'M', '')::NUMERIC * 1024
        WHEN size LIKE '%k' THEN REPLACE(size, 'k', '')::NUMERIC
        ELSE NULL
    END AS size_kb,
    REPLACE(REPLACE(installs, '+', ''), ',', '')::BIGINT AS installs,
    type,
    REPLACE(price, '$', '')::NUMERIC AS price,
    content_rating,
    genres,
    TO_DATE(last_updated, 'DD-Mon-YY') AS last_updated,
    current_ver,
    android_ver
FROM apps;

-- Sanity check
SELECT COUNT(*) AS total, COUNT(rating) AS with_rating FROM apps_clean;


-- =========================================================
-- 3. CATEGORY ANALYSIS — installs vs. rating gap
-- =========================================================

SELECT
    category,
    COUNT(*) AS num_apps,
    ROUND(AVG(rating), 2) AS avg_rating,
    SUM(installs) AS total_installs,
    RANK() OVER (ORDER BY SUM(installs) DESC) AS install_rank,
    RANK() OVER (ORDER BY AVG(rating) DESC) AS rating_rank
FROM apps_clean
WHERE rating IS NOT NULL
GROUP BY category
ORDER BY total_installs DESC;

-- Finding: TOOLS ranks #5 by installs but #32 of 33 by rating —
-- the widest install-vs-rating gap of any major category.

-- % of total installs driven by TOOLS
SELECT
    ROUND(100.0 * SUM(installs) FILTER (WHERE category = 'TOOLS') / SUM(installs), 2)
        AS tools_pct_of_installs
FROM apps_clean;
-- Result: 6.83%


-- =========================================================
-- 4. COHORT ANALYSIS — rating trend by update-recency
-- =========================================================
-- No user-level session data exists in this dataset, so
-- "cohort" here is defined as the month an app was last
-- updated — a proxy for maintenance activity.

SELECT
    DATE_TRUNC('month', last_updated) AS update_cohort,
    COUNT(*) AS num_apps,
    ROUND(AVG(rating), 2) AS avg_rating,
    ROUND(AVG(reviews), 0) AS avg_reviews,
    ROUND(
        AVG(AVG(rating)) OVER (
            ORDER BY DATE_TRUNC('month', last_updated)
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS rating_3mo_moving_avg
FROM apps_clean
WHERE rating IS NOT NULL AND last_updated IS NOT NULL
GROUP BY DATE_TRUNC('month', last_updated)
ORDER BY update_cohort;

-- Finding: average rating climbs from ~4.05 (2017 cohorts)
-- to 4.33 (August 2018 cohort) as update volume increases,
-- suggesting active maintenance correlates with satisfaction.


-- =========================================================
-- 5. A/B TEST — free vs. paid pricing on rating outcome
-- =========================================================

SELECT
    type,
    CASE WHEN rating >= 4.0 THEN 'High' ELSE 'Low' END AS rating_bucket,
    COUNT(*) AS app_count
FROM apps_clean
WHERE rating IS NOT NULL AND type IN ('Free', 'Paid')
GROUP BY type, rating_bucket
ORDER BY type, rating_bucket;

-- Contingency table result:
--   Free / High: 6842   Free / Low: 1878
--   Paid / High:  526   Paid / Low:  121
--
-- Chi-square test of independence (computed in Python via
-- scipy.stats.chi2_contingency, see dashboard.py):
--   chi2 = 2.72, p = 0.099, dof = 1
-- Not statistically significant at 95% confidence — pricing
-- model alone does not appear to drive rating outcomes.
