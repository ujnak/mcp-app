create or replace procedure oj_mcp_vpd_post_handler
(
    p_body         in blob,
    p_current_user in varchar2,
    p_status_code  out number
)
as
    l_scope logger_logs.scope%type := 'oj_mcp_vpd_post_handler';

begin
    logger.log_info('Enter VPD POST Handler', l_scope);
    -- Suppress compile-time errors.
    execute immediate 'begin vpdadmin.oj_mcp_vpd_config.init(:1); end;' using p_current_user;
    -- After initializing the context for VPD, perform the standard POST processing.
    oj_mcp_post_handler(p_body, p_current_user, p_status_code);
    logger.log_info('Leave VPD POST Handler');
end oj_mcp_vpd_post_handler;
/