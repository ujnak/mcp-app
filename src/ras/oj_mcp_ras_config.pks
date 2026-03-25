create or replace package oj_mcp_ras_config
as
/*
 * Configurations related to RAS are consolidated into this package.
 * When configuring different RAS policies or related settings,
 * this package should be updated accordingly.
 */
 
/**
 * Return the dynamic roles assigned to the session.
 */
function get_dynamic_roles
return sys.xs$name_list;

/**
 * Return the name of the namespace that has already been created in RAS.
 */
function get_namespace
return varchar2;

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
end oj_mcp_ras_config;
/