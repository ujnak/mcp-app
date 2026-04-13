create or replace package body oj_mcp_vpd_config
as

G_NAMESPACE constant varchar2(80) := 'emp_dept_ctx';

procedure init(
    p_current_user in varchar2
)
as
    l_employee_id   auth_users.employee_id%type;
    l_department_id auth_users.department_id%type;
begin
    select employee_id, department_id into l_employee_id, l_department_id
    from auth_users
    where authenticated_identity = p_current_user;
    /*
     * Set employee_id and department_id to the application context.
     */
    dbms_session.set_context(G_NAMESPACE,'employee_id',  l_employee_id);
    dbms_session.set_context(G_NAMESPACE,'department_id',l_department_id);
exception
    when no_data_found then
        -- context initialized with null
        dbms_session.set_context(G_NAMESPACE,'employee_id',  null);
        dbms_session.set_context(G_NAMESPACE,'department_id',null);
    when others then
        -- empty app context
        raise;
end init;

end oj_mcp_vpd_config;
/