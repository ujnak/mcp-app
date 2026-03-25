create or replace package body oj_mcp_ras_config
as
/*
 * Configurations related to RAS are consolidated into this package.
 * When configuring different RAS policies or related settings,
 * this package should be updated accordingly.
 */
 
gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

/**
 * Return the dynamic roles assigned to the session.
 */
function get_dynamic_roles
return sys.xs$name_list
as
begin
    return xs$name_list('EMPLOYEE','MCPRUNTIME');
end get_dynamic_roles;

/**
 * Return the name of the namespace that has already been created in RAS.
 */
function get_namespace
return varchar2
as
begin
    return 'HREMP';
end get_namespace;

/**
 * Prepare namespaces.
 */
function prepare_namespace(
    p_username  in varchar2,
    p_namespace in varchar2
)
return sys.dbms_xs_nsattrlist
as
    l_scope logger_logs.scope%type := gc_scope_prefix || 'prepare_namespace';

    l_nsattrlist     sys.dbms_xs_nsattrlist;
    l_employee_id    auth_users.employee_id%type;
    l_department_id  auth_users.department_id%type;
begin
    /*
     * Retrieve the EMPLOYEE_ID and DEPARTMENT_ID of the employee corresponding
     * to the authenticated Microsoft Entra ID user.
     */
    begin
        select employee_id, department_id into l_employee_id, l_department_id
        from auth_users
        where authenticated_identity = p_username;
    exception
        when no_data_found then
            logger.log_error('No record found in auth_users for ' || p_username, l_scope);
            raise;
    end;
    /*
     * Set EMPLOYEE_ID and DEPARTMENT_ID in the namespace template.
     */
    l_nsattrlist := sys.dbms_xs_nsattrlist();
    l_nsattrlist.extend(2);
    l_nsattrlist(1) := sys.dbms_xs_nsattr(p_namespace, 'employee_id', l_employee_id);
    l_nsattrlist(2) := sys.dbms_xs_nsattr(p_namespace, 'department_id', l_department_id);
    return l_nsattrlist;
end prepare_namespace;

end oj_mcp_ras_config;
/