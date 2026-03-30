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
    /*
     * Delete RAS session.
     */
    begin
        oj_mcp_ras_ctx.destroy_session(
            p_current_user => p_current_user,
            p_mcp_session_id => l_session_id
        );
    exception
        when others then
            logger.log_error('Failed to destroy RAS Session.' || sqlerrm, l_scope);
            /* 
             * Failures in session destroy can be safely ignored.
             */
            -- raise;
    end;

    p_status_code := 204;

    logger.log_info('Leave RAS DELETE Handler', l_scope);
end oj_mcp_ras_delete_handler;
/