create or replace function oj_mcp_cancel_request(
    p_module_name in varchar2,
    p_session_id  in varchar2,
    p_request_id  in varchar2
)
/**
 * A function to cancel SQL execution with DBA privileges.
 */
return varchar2
authid definer
as
    l_cancel_sql varchar2(4000);
begin
    select 'alter system cancel sql ''' || sid || ',' || serial# || '''' into l_cancel_sql
    from v$session where action = p_session_id || ':' || p_request_id
        and module = p_module_name and status = 'ACTIVE';
    execute immediate l_cancel_sql;
    return null; -- SQL is cancelled.
exception
    when others then
        return sqlerrm;
end oj_mcp_cancel_request;
/
