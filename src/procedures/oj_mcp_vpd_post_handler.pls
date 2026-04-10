create or replace procedure oj_mcp_vpd_post_handler
(
    p_body         in blob,
    p_current_user in varchar2,
    p_status_code  out number
)
as
    l_scope logger_logs.scope%type := 'oj_mcp_vpd_post_handler';

    l_employee_id   auth_users.employee_id%type;
    l_department_id auth_users.department_id%type;
begin
    logger.log_info('Enter VPD POST Handler', l_scope);
    begin
        select employee_id, department_id into l_employee_id, l_department_id
        from auth_users
        where authenticated_identity = p_current_user;
        vpdadmin.oj_mcp_vpd_config.init(l_employee_id, l_department_id);
    exception
        when no_data_found then
            logger.log_error('no user defined, skip namespace init', l_scope);
            null;
    end;
    oj_mcp_post_handler(p_body, p_current_user, p_status_code);
    logger.log_info('Leave VPD POST Handler');
end oj_mcp_vpd_post_handler;
/