create or replace package body oj_mcp_ras_ctx
as

gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

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