create or replace package oj_mcp_ras_config
as
/*
 * Configurations related to RAS are consolidated into this package.
 * When configuring different RAS policies or related settings,
 * this package should be updated accordingly.
 */
 
/**
 * Return the dynamic roles to be assigned to the ras session.
 * 
 * "MCPRUNTIME" should be included as a dynamic role because
 * MCPRUNTIME is created as a role required for the MCP server to execute.
 */
function get_dynamic_roles
return sys.xs$name_list;

/**
 * Prepare namespaces which will be provided to 
 * sys.dbms_xs_sessions.create_session.
 * 
 * p_username corresponds to the value obtained as :current_user within the ORDS handler.
 */ 
function prepare_namespace(
    p_username  in varchar2
)
return sys.dbms_xs_nsattrlist;
end oj_mcp_ras_config;
/