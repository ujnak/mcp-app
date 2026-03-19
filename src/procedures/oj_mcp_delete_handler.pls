create or replace procedure oj_mcp_delete_handler
(
    p_current_user in varchar2,
    p_status_code  out number
)
as
    l_session_id varchar2(128);
begin
    l_session_id := owa_util.get_cgi_env('Mcp-Session-Id');
    if l_session_id is not null then
        apex_session.delete_session(l_session_id);
    end if;
    p_status_code := 204;
end oj_mcp_delete_handler;
/