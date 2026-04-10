create or replace package body oj_mcp_vpd_config
as

G_NAMESPACE constant varchar2(80) := 'emp_dept_ctx';

procedure init(
    p_employee_id   in number,
    p_department_id in number
)
as
begin
    /*
     * Set employee_id and department_id to the application context.
     */
    dbms_session.set_context(G_NAMESPACE,'employee_id',  p_employee_id);
    dbms_session.set_context(G_NAMESPACE,'department_id',p_department_id);
    exception
    when others then
        -- empty app context
        null;
end init;

end oj_mcp_vpd_config;
/