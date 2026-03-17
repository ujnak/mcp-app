create or replace package body oj_mcp_ras_ctx
as
    C_MCP_SESSION_ID_HEADER constant varchar2(16) := 'Mcp-Session-Id';

/**
 * Prepare namespaces.
 */
function prepare_namespace(
    p_username  in varchar2,
    p_namespace in varchar2
)
return sys.dbms_xs_nsattrlist
as
    l_nsattrlist     sys.dbms_xs_nsattrlist;
    l_employee_id    auth_users.employee_id%type;
    l_department_id  auth_users.department_id%type;
begin
    /*
     * Retrieve the EMPLOYEE_ID and DEPARTMENT_ID of the employee corresponding
     * to the authenticated Microsoft Entra ID user.
     */
    select employee_id, department_id into l_employee_id, l_department_id
    from rasadmin.auth_users
    where authenticated_identity = p_username;
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
function create_session(
    p_current_user   in varchar2
)
return number
as
    l_nsattrlist     sys.dbms_xs_nsattrlist;
    l_id             oj_mcp_ras_sessions.id%type;
    l_ras_session_id oj_mcp_ras_sessions.ras_session_id%type;
begin
    l_nsattrlist := prepare_namespace(
        p_username  => p_current_user,
        p_namespace => 'HREMP'
    );
    /*
     * Create application session.
     */
    sys.dbms_xs_sessions.create_session(
        username    => 'XSGUEST',
        sessionid   => l_ras_session_id,
        namespaces  => l_nsattrlist
    );
    /*
     * Register ras session id
     */
    insert into rasadmin.oj_mcp_ras_sessions(
        username, ras_session_id, status, created_at, updated_at
    )
    values(
        p_current_user, l_ras_session_id, 'CREATED', systimestamp, systimestamp
    ) returning id into l_id;
    return l_id;
end create_session;

/**
 * Attach RAS session to the database session.
 */
procedure attach_session(
    p_current_user  in varchar2,
    p_dynamic_roles in varchar2,
    p_id            out number
)
as
    l_username       oj_mcp_ras_sessions.username%type;
    l_mcp_session_id oj_mcp_ras_sessions.mcp_session_id%type := null;
    l_ras_session_id oj_mcp_ras_sessions.ras_session_id%type;
    l_status         oj_mcp_ras_sessions.status%type;
    l_nsattrlist     sys.dbms_xs_nsattrlist;
begin
    l_mcp_session_id := owa_util.get_cgi_env(C_MCP_SESSION_ID_HEADER);
    /*
     * Create RAS session if no session attached to.
     */
    if l_mcp_session_id is null then
        p_id := create_session(
            p_current_user => p_current_user
        );
        l_status := 'CREATED';
    else
        begin
            select id, status into p_id, l_status from rasadmin.oj_mcp_ras_sessions
            where mcp_session_id = l_mcp_session_id and username = p_current_user
                and status in ('CREATED','DETACHED')
                fetch first 1 rows only;
        exception
            when no_data_found then
                p_id := create_session(
                    p_current_user => p_current_user
                );
                l_status := 'CREATED';
        end;
    end if;
    /*
     * get ras session id
     *     STATUS must be CREATED or DETACHED
     */
    select ras_session_id into l_ras_session_id
    from rasadmin.oj_mcp_ras_sessions
    where id = p_id;
    /*
     * Attach RAS session to the current database session.
     */
    sys.dbms_xs_sessions.attach_session(l_ras_session_id);

    /*
     * セッションに外部ユーザーを割り当てる。
     * 動的ロールはEMPLOYEE固定。
     */
    l_nsattrlist := prepare_namespace(
        p_username  => p_current_user,
        p_namespace => 'HREMP'
    );
    if l_status = 'CREATED' then
        sys.dbms_xs_sessions.assign_user(
            username             => p_current_user,
            enable_dynamic_roles => xs$name_list(p_dynamic_roles),
            is_external          => true
        );
    else
        sys.dbms_xs_sessions.switch_user(
            username             => p_current_user,
            namespaces           => l_nsattrlist 
        );
    end if;

    /* セッションを保存する。 */
    sys.dbms_xs_sessions.save_session;
end attach_session;

/**
 * Detach the RAS session from the database session.
 */
procedure detach_session(
    p_id           in number default null
)
as
    l_mcp_session_id oj_mcp_ras_sessions.mcp_session_id%type;
    l_ras_session_id raw(16);
begin
    l_mcp_session_id := owa_util.get_cgi_env(C_MCP_SESSION_ID_HEADER);
    begin
        update rasadmin.oj_mcp_ras_sessions
            set status = 'DETACHED',
                mcp_session_id = l_mcp_session_id,
                updated_at = systimestamp
        where id = p_id;
    exception
        when no_data_found then
            null;
    end;
    commit;
end detach_session;

/**
 * Destroy RAS session.
 */
procedure destroy_session(
    p_current_user in varchar2
)
as
    pragma autonomous_transaction;
    l_mcp_session_id rasadmin.oj_mcp_ras_sessions.mcp_session_id%type;
begin
    l_mcp_session_id := owa_util.get_cgi_env(C_MCP_SESSION_ID_HEADER);
    for r in (
        select ras_session_id from rasadmin.oj_mcp_ras_sessions
        where mcp_session_id = l_mcp_session_id and username = p_current_user
          and status = 'DETACHED'
    )
    loop
        sys.dbms_xs_sessions.destroy_session(r.ras_session_id);
    end loop;
    commit;
end destroy_session;

end oj_mcp_ras_ctx;
/