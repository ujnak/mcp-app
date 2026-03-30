create or replace package oj_mcp_app_methods
authid current_user
as

/**
 * Set APEX and Logger log level from  MCP log level.
 *
 * MCP Inspector sets following log levels.
 * debug, info, notice, warning, error, critical, alert, emergency
 *
 * APEX debug accepts following log levels.
 * error(1), warn(2), info(4), trace(6)
 *
 * OraOpenSource Logger accepts following log levels.
 * OFF(0), PERMANENT(1), ERROR(2), WARNING(4), INFORMATION(8),
 * DEBUG(16) and TIMING
 *
 * MCP Inspector | APEX     | Logger
 * --------------|----------|----------------
 * debug         | trace(6) | DEBUG(16)
 * info          | info(4)  | INFORMATION(8)
 * notice        | warn(2)  | WARNING(4)
 * warning       | warn(2)  | WARNING(4)
 * error         | error(1) | ERROR(2)
 * critical      | error(1) | PERMANENT(1)
 * alert         | error(1) | PERMANENT(1)
 * emergency     | error(1) | PERMANENT(1)
 */
procedure set_log_level(
    p_log_level in varchar2
);

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