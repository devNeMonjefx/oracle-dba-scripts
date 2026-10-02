-- ============================================================
-- Oracle DBA Utility Script
-- User Privilege Audit
--
-- File: 01_user_privilege_audit.sql
--
-- Purpose:
-- Generate a readable privilege and account report for a
-- specific Oracle database user.
--
-- Run using an account with access to DBA catalog views.
-- Example: LAB_DBA with SELECT_CATALOG_ROLE.
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
-- Target user
-- ------------------------------------------------------------

DEFINE target_user = APP_READER


-- ------------------------------------------------------------
-- Column formatting
-- ------------------------------------------------------------

COLUMN username             FORMAT A18
COLUMN account_status       FORMAT A18
COLUMN default_tablespace   FORMAT A20
COLUMN temporary_tablespace FORMAT A20
COLUMN profile              FORMAT A18

COLUMN grantee              FORMAT A22
COLUMN granted_role         FORMAT A25
COLUMN admin_option         FORMAT A12
COLUMN default_role         FORMAT A12

COLUMN privilege            FORMAT A35
COLUMN owner                FORMAT A18
COLUMN table_name           FORMAT A28
COLUMN grantable            FORMAT A10

COLUMN tablespace_name      FORMAT A22
COLUMN used_mb              FORMAT 9999990.00
COLUMN max_mb               FORMAT A15

COLUMN executing_user       FORMAT A20
COLUMN source               FORMAT A28
COLUMN access_detail        FORMAT A55


PROMPT
PROMPT ============================================================
PROMPT              ORACLE USER PRIVILEGE AUDIT
PROMPT ============================================================
PROMPT
PROMPT Target user: &&target_user
PROMPT


-- ============================================================
-- 1. EXECUTION CONTEXT
-- ============================================================

PROMPT ============================================================
PROMPT 1. EXECUTION CONTEXT
PROMPT ============================================================

SELECT
    USER AS executing_user
FROM dual;

PROMPT

SHOW CON_NAME;

PROMPT


-- ============================================================
-- 2. ACCOUNT INFORMATION
-- ============================================================

PROMPT ============================================================
PROMPT 2. ACCOUNT INFORMATION
PROMPT ============================================================

SELECT
    username,
    account_status,
    default_tablespace,
    temporary_tablespace,
    profile
FROM dba_users
WHERE username = UPPER('&&target_user');

PROMPT


-- ============================================================
-- 3. ASSIGNED ROLES
-- ============================================================

PROMPT ============================================================
PROMPT 3. ASSIGNED ROLES
PROMPT ============================================================

SELECT
    granted_role,
    admin_option,
    default_role
FROM dba_role_privs
WHERE grantee = UPPER('&&target_user')
ORDER BY granted_role;

PROMPT


-- ============================================================
-- 4. DIRECT SYSTEM PRIVILEGES
-- ============================================================

PROMPT ============================================================
PROMPT 4. DIRECT SYSTEM PRIVILEGES
PROMPT ============================================================

SELECT
    privilege,
    admin_option
FROM dba_sys_privs
WHERE grantee = UPPER('&&target_user')
ORDER BY privilege;

PROMPT


-- ============================================================
-- 5. DIRECT OBJECT PRIVILEGES
-- ============================================================

PROMPT ============================================================
PROMPT 5. DIRECT OBJECT PRIVILEGES
PROMPT ============================================================

SELECT
    owner,
    table_name,
    privilege,
    grantable
FROM dba_tab_privs
WHERE grantee = UPPER('&&target_user')
ORDER BY
    owner,
    table_name,
    privilege;

PROMPT


-- ============================================================
-- 6. TABLESPACE QUOTAS
-- ============================================================

PROMPT ============================================================
PROMPT 6. TABLESPACE QUOTAS
PROMPT ============================================================

SELECT
    tablespace_name,

    ROUND(
        bytes / 1024 / 1024,
        2
    ) AS used_mb,

    CASE
        WHEN max_bytes = -1 THEN
            'UNLIMITED'
        ELSE
            TO_CHAR(
                ROUND(
                    max_bytes / 1024 / 1024,
                    2
                )
            )
    END AS max_mb

FROM dba_ts_quotas

WHERE username =
    UPPER('&&target_user')

ORDER BY
    tablespace_name;

PROMPT


-- ============================================================
-- 7. OBJECT PRIVILEGES THROUGH DIRECT ROLES
-- ============================================================

PROMPT ============================================================
PROMPT 7. OBJECT PRIVILEGES THROUGH DIRECT ROLES
PROMPT ============================================================

SELECT
    rp.granted_role,
    tp.owner,
    tp.table_name,
    tp.privilege,
    tp.grantable

FROM dba_role_privs rp

JOIN dba_tab_privs tp
    ON tp.grantee = rp.granted_role

WHERE rp.grantee =
    UPPER('&&target_user')

ORDER BY
    rp.granted_role,
    tp.owner,
    tp.table_name,
    tp.privilege;

PROMPT


-- ============================================================
-- 8. ACCESS SUMMARY
-- ============================================================

PROMPT ============================================================
PROMPT 8. ACCESS SUMMARY
PROMPT ============================================================

SELECT
    privilege_source,
    access_detail
FROM (
    SELECT
        'DIRECT SYSTEM PRIVILEGE' AS privilege_source,
        privilege AS access_detail
    FROM dba_sys_privs
    WHERE grantee = UPPER('&&target_user')

    UNION ALL

    SELECT
        'ASSIGNED ROLE' AS privilege_source,
        granted_role AS access_detail
    FROM dba_role_privs
    WHERE grantee = UPPER('&&target_user')

    UNION ALL

    SELECT
        'ROLE OBJECT PRIVILEGE' AS privilege_source,
        privilege
            || ' ON '
            || owner
            || '.'
            || table_name AS access_detail
    FROM dba_tab_privs
    WHERE grantee IN (
        SELECT granted_role
        FROM dba_role_privs
        WHERE grantee = UPPER('&&target_user')
    )
)
ORDER BY
    privilege_source,
    access_detail;

PROMPT


-- ============================================================
-- 9. AUDIT TOTALS
-- ============================================================

PROMPT ============================================================
PROMPT 9. AUDIT TOTALS
PROMPT ============================================================

COLUMN roles_count                    FORMAT 999
COLUMN system_privileges_count        FORMAT 999
COLUMN direct_object_privileges_count FORMAT 999
COLUMN role_object_privileges_count   FORMAT 999

SELECT
    UPPER('&&target_user')
        AS username,

    (
        SELECT account_status
        FROM dba_users
        WHERE username =
            UPPER('&&target_user')
    ) AS account_status,

    (
        SELECT COUNT(*)
        FROM dba_role_privs
        WHERE grantee =
            UPPER('&&target_user')
    ) AS roles_count,

    (
        SELECT COUNT(*)
        FROM dba_sys_privs
        WHERE grantee =
            UPPER('&&target_user')
    ) AS system_privileges_count,

    (
        SELECT COUNT(*)
        FROM dba_tab_privs
        WHERE grantee =
            UPPER('&&target_user')
    ) AS direct_object_privileges_count,

    (
        SELECT COUNT(*)

        FROM dba_tab_privs

        WHERE grantee IN (
            SELECT granted_role
            FROM dba_role_privs
            WHERE grantee =
                UPPER('&&target_user')
        )
    ) AS role_object_privileges_count

FROM dual;

PROMPT
PROMPT ============================================================
PROMPT                    AUDIT COMPLETE
PROMPT ============================================================
PROMPT


-- ------------------------------------------------------------
-- Restore SQL feedback
-- ------------------------------------------------------------

SET FEEDBACK ON