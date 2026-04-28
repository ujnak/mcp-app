create or replace package oj_mcp_run_sql_async
authid current_user
as

function submit(
    p_args in clob
)
return clob;

function get(
    p_args in clob
)
return clob;

function result(
    p_args in clob
)
return clob;

end oj_mcp_run_sql_async;