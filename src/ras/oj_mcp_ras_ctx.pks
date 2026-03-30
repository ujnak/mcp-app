create or replace package oj_mcp_ras_ctx
    authid current_user
as

/**
 * Get cookie name from username and session id.
 */
function get_cookie_name(
    p_username       in varchar2,
    p_mcp_session_id in varchar2
)
return varchar2;

/**
 * Create an RAS session.
 */
procedure create_session(
    p_current_user   in varchar2,
    p_mcp_session_id in varchar2,
    p_nsattrlist     in sys.dbms_xs_nsattrlist
);

/**
 * Destroy the RAS session.
 */
procedure destroy_session(
    p_current_user   in varchar2,
    p_mcp_session_id in varchar2
);

end oj_mcp_ras_ctx;
/
