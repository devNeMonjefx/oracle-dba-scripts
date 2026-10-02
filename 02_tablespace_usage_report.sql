-- ============================================================
-- Oracle DBA Utility Script
-- Tablespace Usage Report
--
-- File: 02_tablespace_usage_report.sql
--
-- Purpose:
-- Generate a storage usage report for permanent Oracle
-- tablespaces.
--
-- The report shows:
--   - Tablespace name
--   - Status
--   - Total allocated space
--   - Used space
--   - Free space
--   - Usage percentage
--   - Maximum autoextend capacity
--   - Health status
--
-- Requirements:
-- Run using an account with access to Oracle DBA catalog views,
-- such as LAB_DBA with SELECT_CATALOG_ROLE.
--
-- Tested with:
-- Oracle Database 21c XE
-- XEPDB1
-- ============================================================


-- ------------------------------------------------------------
-- SQL*Plus / SQL Developer output configuration
-- ------------------------------------------------------------

SET VERIFY OFF
SET FEEDBACK OFF
SET HEADING ON
SET PAGESIZE 100
SET LINESIZE 180
SET TAB OFF
SET TRIMSPOOL ON


-- ------------------------------------------------------------
-- Threshold configuration
-- ------------------------------------------------------------

DEFINE warning_threshold = 80
DEFINE critical_threshold = 90


-- ------------------------------------------------------------
-- Column formatting
-- ------------------------------------------------------------

COLUMN tablespace_name FORMAT A24
COLUMN status          FORMAT A10

COLUMN total_mb        FORMAT 9999990.00
COLUMN used_mb         FORMAT 9999990.00
COLUMN free_mb         FORMAT 9999990.00
COLUMN max_mb          FORMAT 9999990.00
COLUMN used_pct        FORMAT 990.00

COLUMN health_status   FORMAT A12


PROMPT
PROMPT ============================================================
PROMPT               ORACLE TABLESPACE USAGE REPORT
PROMPT ============================================================
PROMPT
PROMPT Warning threshold : &&warning_threshold%
PROMPT Critical threshold: &&critical_threshold%
PROMPT


-- ============================================================
-- 1. EXECUTION CONTEXT
-- ============================================================

PROMPT ============================================================
PROMPT 1. EXECUTION CONTEXT
PROMPT ============================================================

COLUMN executing_user FORMAT A20

SELECT
    USER AS executing_user
FROM dual;

PROMPT

SHOW CON_NAME;

PROMPT


-- ============================================================
-- 2. TABLESPACE USAGE
-- ============================================================

PROMPT ============================================================
PROMPT 2. TABLESPACE USAGE
PROMPT ============================================================

WITH
datafiles AS (
    SELECT
        tablespace_name,

        SUM(bytes)
            / 1024
            / 1024 AS total_mb,

        SUM(
            CASE
                WHEN autoextensible = 'YES'
                    THEN maxbytes
                ELSE bytes
            END
        )
            / 1024
            / 1024 AS max_mb

    FROM dba_data_files

    GROUP BY
        tablespace_name
),

free_space AS (
    SELECT
        tablespace_name,

        SUM(bytes)
            / 1024
            / 1024 AS free_mb

    FROM dba_free_space

    GROUP BY
        tablespace_name
),

usage_report AS (
    SELECT
        t.tablespace_name,
        t.status,

        ROUND(
            d.total_mb,
            2
        ) AS total_mb,

        ROUND(
            d.total_mb
            - NVL(f.free_mb, 0),
            2
        ) AS used_mb,

        ROUND(
            NVL(f.free_mb, 0),
            2
        ) AS free_mb,

        ROUND(
            d.max_mb,
            2
        ) AS max_mb,

        ROUND(
            (
                (
                    d.total_mb
                    - NVL(f.free_mb, 0)
                )
                / NULLIF(
                    d.total_mb,
                    0
                )
            ) * 100,
            2
        ) AS used_pct

    FROM dba_tablespaces t

    JOIN datafiles d
        ON d.tablespace_name =
           t.tablespace_name

    LEFT JOIN free_space f
        ON f.tablespace_name =
           t.tablespace_name

    WHERE t.contents = 'PERMANENT'
)

SELECT
    tablespace_name,
    status,
    total_mb,
    used_mb,
    free_mb,
    max_mb,
    used_pct,

    CASE
        WHEN used_pct >= &&critical_threshold
            THEN 'CRITICAL'

        WHEN used_pct >= &&warning_threshold
            THEN 'WARNING'

        ELSE 'OK'
    END AS health_status

FROM usage_report

ORDER BY
    used_pct DESC,
    tablespace_name;

PROMPT


-- ============================================================
-- 3. TABLESPACE SUMMARY
-- ============================================================

PROMPT ============================================================
PROMPT 3. TABLESPACE SUMMARY
PROMPT ============================================================

COLUMN total_tablespaces     FORMAT 999
COLUMN healthy_tablespaces   FORMAT 999
COLUMN warning_tablespaces   FORMAT 999
COLUMN critical_tablespaces  FORMAT 999

WITH
datafiles AS (
    SELECT
        tablespace_name,

        SUM(bytes)
            / 1024
            / 1024 AS total_mb

    FROM dba_data_files

    GROUP BY
        tablespace_name
),

free_space AS (
    SELECT
        tablespace_name,

        SUM(bytes)
            / 1024
            / 1024 AS free_mb

    FROM dba_free_space

    GROUP BY
        tablespace_name
),

usage_report AS (
    SELECT
        t.tablespace_name,

        (
            (
                d.total_mb
                - NVL(f.free_mb, 0)
            )
            / NULLIF(
                d.total_mb,
                0
            )
        ) * 100 AS used_pct

    FROM dba_tablespaces t

    JOIN datafiles d
        ON d.tablespace_name =
           t.tablespace_name

    LEFT JOIN free_space f
        ON f.tablespace_name =
           t.tablespace_name

    WHERE t.contents = 'PERMANENT'
)

SELECT
    COUNT(*) AS total_tablespaces,

    SUM(
        CASE
            WHEN used_pct < &&warning_threshold
                THEN 1
            ELSE 0
        END
    ) AS healthy_tablespaces,

    SUM(
        CASE
            WHEN used_pct >= &&warning_threshold
             AND used_pct < &&critical_threshold
                THEN 1
            ELSE 0
        END
    ) AS warning_tablespaces,

    SUM(
        CASE
            WHEN used_pct >= &&critical_threshold
                THEN 1
            ELSE 0
        END
    ) AS critical_tablespaces

FROM usage_report;

PROMPT


-- ============================================================
-- 4. TABLESPACES REQUIRING ATTENTION
-- ============================================================

PROMPT ============================================================
PROMPT 4. TABLESPACES REQUIRING ATTENTION
PROMPT ============================================================

WITH
datafiles AS (
    SELECT
        tablespace_name,

        SUM(bytes)
            / 1024
            / 1024 AS total_mb

    FROM dba_data_files

    GROUP BY
        tablespace_name
),

free_space AS (
    SELECT
        tablespace_name,

        SUM(bytes)
            / 1024
            / 1024 AS free_mb

    FROM dba_free_space

    GROUP BY
        tablespace_name
),

usage_report AS (
    SELECT
        t.tablespace_name,

        ROUND(
            (
                (
                    d.total_mb
                    - NVL(f.free_mb, 0)
                )
                / NULLIF(
                    d.total_mb,
                    0
                )
            ) * 100,
            2
        ) AS used_pct

    FROM dba_tablespaces t

    JOIN datafiles d
        ON d.tablespace_name =
           t.tablespace_name

    LEFT JOIN free_space f
        ON f.tablespace_name =
           t.tablespace_name

    WHERE t.contents = 'PERMANENT'
)

SELECT
    tablespace_name,
    used_pct,

    CASE
        WHEN used_pct >= &&critical_threshold
            THEN 'CRITICAL'

        ELSE 'WARNING'
    END AS health_status

FROM usage_report

WHERE used_pct >= &&warning_threshold

ORDER BY
    used_pct DESC;

PROMPT
PROMPT ============================================================
PROMPT                  REPORT COMPLETE
PROMPT ============================================================
PROMPT

SET FEEDBACK ON