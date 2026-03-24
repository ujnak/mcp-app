-- Although is_autonomous in PLSQL_CCFLAGS is configured via ALTER SESSION,
-- it is also necessary to configure it using ALTER SYSTEM,
-- considering that packages may be compiled automatically.
alter session set PLSQL_CCFLAGS = 'is_autonomous:FALSE';
@@install-all.sql
