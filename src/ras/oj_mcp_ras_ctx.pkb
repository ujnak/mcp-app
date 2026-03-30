create or replace package body oj_mcp_ras_ctx
as

gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

/**
 * Get cookie name from username and session id.
 */
function get_cookie_name(
    p_username       in varchar2,
    p_mcp_session_id in varchar2
)
return varchar2
as
begin
    return p_username || '-' || p_mcp_session_id;
end get_cookie_name;

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
    l_cookie := get_cookie_name(p_current_user, p_mcp_session_id);
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
    l_scope logger_logs.scope%type := gc_scope_prefix || 'destroy_session';

    l_cookie varchar2(1024);
    l_ras_session_id raw(16);
begin
    l_cookie := get_cookie_name(p_current_user, p_mcp_session_id);

    /* 
     * TODO:
     * Searching DBA_XS_SESSIONS to extract the sessionid from the cookie 
     * requires privileges that are excessively broad. We should consider an alternative approach,
     * such as implementing a dedicated function to retrieve the sessionid from the cookie.
     */
    select sessionid into l_ras_session_id from dba_xs_sessions where cookie = l_cookie;
    sys.dbms_xs_sessions.destroy_session(
        sessionid => l_ras_session_id,
        force => false
    );
exception
    when no_data_found then
        logger.log_error('No XS session found for cookie ' || l_cookie, l_scope);
        raise;
end destroy_session;

end oj_mcp_ras_ctx;
/