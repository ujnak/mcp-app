set define off
/* -----------------------------------------------------------------------------
 * Define UI resource for tool 'get_current_user'.
 * -----------------------------------------------------------------------------
 */
declare
    l_text        clob;
    l_resource_id number;
    l_tool_id     number;
begin
    /*
     * Define the HTML user interface to be embedded in an iframe. 
     * Define the HTML/JavaScript/CSS inline.
     * There are many tasks to address, and I will consider the implementation 
     * approach going forward.
     */
    l_text := q'~<!DOCTYPE html><html><body><button>Click Me!</button></html>~';
    merge into oj_mcp_app_resources t
    using (
        select
            'get_current_user'                   resource_name,
            'ui://get-current-user/mcp-app.html' resource_uri,
            'text/html;profile=mcp-app'          mime_type,
            l_text                               text
        from dual
    ) s
    on (t.resource_name = s.resource_name)
    when matched then
        update set
            t.resource_uri  = s.resource_uri,
            t.mime_type     = s.mime_type,
            t.text          = s.text
    when not matched then
        insert (resource_name, resource_uri, mime_type, text)
        values (s.resource_name, s.resource_uri, s.mime_type, s.text)
    ;

    select id into l_tool_id from uc_ai_tools where code = 'get_current_user';
    select id into l_resource_id from oj_mcp_app_resources where resource_name = 'get_current_user';
   
    merge into oj_mcp_tools_extras t
    using (
        select l_tool_id tool_id, l_resource_id resource_id from dual
    ) s
    on (t.tool_id = s.tool_id)
    when matched then
        update set
            t.resource_id = s.resource_id
    when not matched then
        insert (tool_id, resource_id) values(s.tool_id, s.resource_id)
    ;
    commit;
end;
/