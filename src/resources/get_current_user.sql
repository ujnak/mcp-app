set define off
/* -----------------------------------------------------------------------------
 * Define UI resource for tool 'get_current_user'.
 * -----------------------------------------------------------------------------
 */
declare
    l_text        clob;
    l_resource_id number;
    l_tool_id     number;
    l_update_user    varchar2(80);
    l_update_time    timestamp;
begin
    l_update_user := sys_context('USERENV', 'CURRENT_USER');
    l_update_time := current_timestamp;

    /*
     * Define the HTML user interface to be embedded in an iframe. 
     * Define the HTML/JavaScript/CSS inline.
     * There are many tasks to address, and I will consider the implementation 
     * approach going forward.
     */
    l_text := q'~<!DOCTYPE html><html><body><button>Click Me!</button></html>~';
    merge into oj_mcp_ui_resources t
    using (
        select
            'get_current_user'                   name,
            'ui://get-current-user/mcp-app.html' uri,
            'text/html;profile=mcp-app'          mime_type,
            l_text                               text
        from dual
    ) s
    on (t.name = s.name)
    when matched then
        update set
            t.uri         = s.uri,
            t.mime_type   = s.mime_type,
            t.text        = s.text,
            t.updated_by  = l_update_user,
            t.updated_at  = l_update_time
    when not matched then
        insert (name, uri, mime_type, text, created_by, created_at, updated_by, updated_at)
        values (s.name, s.uri, s.mime_type, s.text, l_update_user, l_update_time, l_update_user, l_update_time)
    ;

    select id into l_tool_id from uc_ai_tools where code = 'get_current_user';
    select id into l_resource_id from oj_mcp_ui_resources where name = 'get_current_user';
   
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

    delete from oj_mcp_ui_csp_domains where resource_id = l_resource_id;
    insert into oj_mcp_ui_csp_domains(resource_id, domain_type, domain, created_by, created_at, updated_by, updated_at)
    values(l_resource_id, 'RESOURCE', 'https://cdn.jsdelivr.net', l_update_user, l_update_time, l_update_user, l_update_time);

    commit;
end;
/