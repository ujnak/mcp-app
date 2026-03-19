create or replace procedure oj_mcp_ras_delete_handler
(
    p_current_user in varchar2,
    p_status_code  out number
)
as
    l_scope logger_logs.scope%type := 'oj_mcp_ras_delete_handler';

    l_session_id varchar2(128);
begin
    logger.log_info('Enter RAS DELETE Handler', l_scope);

    l_session_id := owa_util.get_cgi_env('Mcp-Session-Id');
    if l_session_id is not null then
        apex_session.delete_session(l_session_id);
    end if;
    p_status_code := 204;

    logger.log_info('Leave RAS DELETE Handler', l_scope);
end oj_mcp_ras_delete_handler;
/