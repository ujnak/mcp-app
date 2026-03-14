create or replace package oj_mcp_app_utils
as

/**
 * Update text in OJ_MCP_UI_RESOURCES by HTML bundle generated from APEX page definition.
 * 
 * Example:
begin
oj_mcp_app_utils.update_app_text_from_apex_page(
    p_resource_name => 'get_current_user',
    p_resource_uri  => 'ui://get-current-user/mcp-app.html',
    p_page_url      => 'http://host.docker.internal:8181/ords/r/apexdev/sampleserver/get-current-user'
);
end;
 */
procedure update_app_text_from_apex_page(
    p_resource_name         in varchar2,
    p_resource_uri          in varchar2,
    p_page_url              in varchar2
);

end oj_mcp_app_utils;
/
