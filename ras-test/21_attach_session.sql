set serveroutput on
begin
    oj_mcp_ras_ctx.attach_session(
        p_current_user => '&CURRENT_USER',
        p_mcp_session_id => '&MCP_SESSION_ID',
        p_dynamic_roles => sys.xs$name_list('EMPLOYEE','MCPRUNTIME')
    );
end;
/
