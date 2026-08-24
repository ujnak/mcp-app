declare
    e_object_not_found exception;
    pragma exception_init(e_object_not_found, -4043);

    procedure drop_legacy_procedure(p_name in varchar2) is
    begin
        execute immediate 'drop procedure ' || dbms_assert.simple_sql_name(p_name);
    exception
        when e_object_not_found then
            null;
    end drop_legacy_procedure;
begin
    drop_legacy_procedure('OJ_MCP_DELETE_HANDLER');
    drop_legacy_procedure('OJ_MCP_RAS_DELETE_HANDLER');
end;
/

@@src/ras/oj_mcp_ras_ctx.pks
@@src/ras/oj_mcp_ras_ctx.pkb
@@src/packages/oj_mcp_jsonrpc_utils.pks
@@src/packages/oj_mcp_jsonrpc_utils.pkb
@@src/packages/oj_mcp_app_utils.pks
@@src/packages/oj_mcp_app_utils.pkb
@@src/packages/oj_mcp_app_methods.pks
@@src/packages/oj_mcp_app_methods.pkb
@@src/packages/oj_mcp_app_server.pks
@@src/packages/oj_mcp_app_server.pkb
-- procedures.
@@src/procedures/oj_mcp_post_handler.pls
@@src/procedures/oj_mcp_ras_post_handler.pls
@@src/procedures/oj_mcp_vpd_post_handler.pls
