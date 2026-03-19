create or replace package body oj_mcp_ras_ctx
as

gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

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

/**
 * Create RAS Session.
 */
procedure create_session(
    p_current_user   in varchar2,
    p_mcp_session_id in varchar2,
    p_nsattrlist     in sys.dbms_xs_nsattrlist
)
as
    l_scope logger_logs.scope%type := gc_scope_prefix || 'create_session';

    l_cookie         varchar2(1024);
    l_ras_session_id raw(16);
begin
    l_cookie := p_current_user || '-' || p_mcp_session_id;
    /*
     * Create application session.
     */
    sys.dbms_xs_sessions.create_session(
        username    => p_current_user,
        sessionid   => l_ras_session_id,
        is_external => true,
        cookie      => l_cookie,
        namespaces  => p_nsattrlist
    );
    logger.log_info('XS Session created. ' || l_ras_session_id, l_scope);
end create_session;

/**
 * Destroy RAS session.
 */
procedure destroy_session(
    p_current_user  in varchar2,
    p_mcp_session_id in varchar2
)
as
    l_cookie varchar2(1024);
    l_ras_session_id raw(16);
begin
    l_cookie := p_current_user || '-' || p_mcp_session_id;
    select sessionid into l_ras_session_id from dba_xs_sessions where cookie = l_cookie;
    sys.dbms_xs_sessions.destroy_session(
        sessionid => l_ras_session_id,
        force => false
    );
end destroy_session;

end oj_mcp_ras_ctx;
/