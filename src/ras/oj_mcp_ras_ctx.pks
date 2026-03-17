create or replace package oj_mcp_ras_ctx authid current_user
as

/**
 * If an RAS session associated with the MCP session ID obtained from Mcp-Session-Id 
 * and the user ID exists,
 * attach that session to the database session. Otherwise, create an RAS session 
 * and then attach it to the database session.
 */
procedure attach_session(
    p_current_user  in varchar2,
    p_dynamic_roles in varchar2,
    p_id            out number
);

/**
 * Detach the RAS session from the database session.
 */
procedure detach_session(
    p_id in number default null
);

/**
 * Destroy the RAS session.
 */
procedure destroy_session(
    p_current_user in varchar2
);

end oj_mcp_ras_ctx;
/
