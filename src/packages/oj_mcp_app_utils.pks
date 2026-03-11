create or replace package oj_mcp_app_utils
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
function negoticate_client_server_capabilities(
    p_client_capabilities_json in json_object_t
) return json_object_t;

/**
 * Update text in OJ_MCP_APP_RESOURCES by HTML bundle generated from APEX page definition.
 * 
 * Example:
begin
oj_mcp_app_utils.update_app_text_from_apex_page(
    p_resource_name => 'get_current_user',
    p_resource_uri  => 'ui://get-current-user/mcp-app.html',
    p_application_alias => 'sampleserver',
    p_page_alias => 'get-current-user',
    p_workspace => 'apexdev',
    p_apex_path => 'http://host.docker.internal:8181/ords/r'
);
end;
 */
procedure update_app_text_from_apex_page(
    p_resource_name         in varchar2,
    p_resource_uri          in varchar2,
    p_application_alias     in varchar2,
    p_page_alias            in varchar2,
    p_workspace             in varchar2,
    p_apex_path             in varchar2         
);

end oj_mcp_app_utils;
/
