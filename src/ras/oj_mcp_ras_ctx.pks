create or replace package oj_mcp_ras_ctx
    authid current_user
as

/**
 * Prepare the application context HREMP by querying the mapping table AUTH_USERS 
 * using the authenticated user :current_user, 
 * and set the corresponding employee_id and department_id.
 */
function prepare_namespace(
    p_username  in varchar2,
    p_namespace in varchar2
)
return sys.dbms_xs_nsattrlist;

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
