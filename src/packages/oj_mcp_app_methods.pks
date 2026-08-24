create or replace package oj_mcp_app_methods
authid current_user
as

/**
 * Client Server capability negotiation.
 *
 * @param p_client_capabilities_json JSON object containing capabilities sent by the client.
 * @return JSON object containing the server's capabilities to be sent back to the client.
 */
function negotiate_client_server_capabilities(
    p_client_capabilities_json in json_object_t
) return json_object_t;

/**
 * Generate JSON array of tools for tools/list.
 */
function generate_array_for_list_tools(
    p_context in varchar2
)
return json_array_t;

/**
 * Generate JSON array of content for tools/call.
 */
function generate_object_for_tools_call(
    p_name           in varchar2,
    p_args           in json_object_t,
    p_ras_config_pkg in varchar2 default null,
    p_current_user   in varchar2 default null,
    p_mcp_session_id in varchar2 default null
)
return json_object_t;

/**
 * Generate JSON array of resources for responses/list.
 *
 * Specify in p_content the tags used to restrict the resources included in the list.
 */
function generate_array_for_list_ui_resources(
    p_context in varchar2
)
return json_array_t;

/** 
 * Generate JSON array contents for resources/read.
 */
function generate_array_for_read_ui_resource(
    p_uri in oj_mcp_ui_resources.uri%type
) return json_array_t;

end oj_mcp_app_methods;
/
