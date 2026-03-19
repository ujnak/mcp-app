set serveroutput on
declare
    l_nsattrlist sys.dbms_xs_nsattrlist;
    l_mcp_session_id varchar2(128);
begin
    l_nsattrlist := oj_mcp_ras_ctx.prepare_namespace(
        p_username => '&CURRENT_USER',
        p_namespace => 'HREMP'
    );
    l_mcp_session_id := to_char(trunc(dbms_random.value(1,1000)));
    dbms_output.put_line('MCP Session Id: ' || l_mcp_session_id);
    oj_mcp_ras_ctx.create_session(
        p_current_user   => '&CURRENT_USER',
        p_mcp_session_id => l_mcp_session_id,
        p_nsattrlist     => l_nsattrlist
    );
end;
/

