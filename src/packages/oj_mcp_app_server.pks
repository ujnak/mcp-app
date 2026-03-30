/* -----------------------------------------------------------------------------
 * MCP Server implementation for ORDS REST API.
 * -----------------------------------------------------------------------------
 */
create or replace package oj_mcp_app_server
authid current_user
as
/**
 * Standard Error Code of JSON-RPC.
 */
C_PARSE_ERROR      constant number := -32700;
C_INVALID_REQUEST  constant number := -32600;
C_METHOD_NOT_FOUND constant number := -32601;
C_INVALID_PARAMS   constant number := -32602;
C_INTERNAL_ERROR   constant number := -32603;

/*
 * Setters.
 */
procedure set_dynamic_roles(
    value in sys.xs$name_list
);

/**
 * Execute it as the POST handler for the ORDS REST API template named "mcp",
 *
 * @param p_script_name script name from owa_util.get_cgi_env('SCRIPT_NAME') || '/mcp'.
 * @param p_username    username from :current_user within ORDS REST handler.
 * @param p_request     request body from :body. payload of JSON-RPC request.
 * @param p_response    response BLOB. payload of JSON-RPC response.
 *                      NULL for notifications.
 * @param p_session_id  session ID created by apex_session.create_session.
 * @param p_status_code HTTP status code for the response. Typically 200.
 */
procedure ords_handler(
    p_script_name   in  varchar2
    ,p_username     in  varchar2
    ,p_request      in  blob
    ,p_response     out blob
    ,p_session_id   out varchar2
    ,p_status_code  out number
    ,p_ras_config_pkg in varchar2 default null
);

end oj_mcp_app_server;
/