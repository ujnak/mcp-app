declare
    /*  Tools */
    type t_apps is table of varchar2(40);
    l_apps t_apps := t_apps(
        'get-time-preact',
        'get-time-react',
        'get-time-solid',
        'get-time-svelte',
        'get-time-vue'
    );
    l_app varchar2(40);
    C_INPUT_SCHEMA constant json_object_t :=  json_object_t.parse('{"$schema":"http://json-schema.org/draft-07/schema#","type":"object"}');
    C_OUTPUT_SCHEMA constant clob := q'~
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "time": {
      "type": "string"
    }
  }
}    
    ~';
    l_tool_id uc_ai_tools.id%type;
    /* UI resources */
    l_resource_id number;
    l_update_user    varchar2(80);
    l_update_time    timestamp;
    C_DEFAULT_HTML constant clob := q'~<!DOCTYPE html><html><body></body></html>~';
begin
    l_update_user := sys_context('USERENV', 'CURRENT_USER');
    l_update_time := current_timestamp;
    for i in 1..l_apps.count
    loop
        l_app := l_apps(i);
        /* delete and create tool */
        delete from uc_ai_tools where code = l_app;
        l_tool_id := uc_ai_tools_api.create_tool_from_schema(
            p_tool_code => l_app,
            p_description => 'Returns the current server time as an ISO 8601 string.',
            p_function_call => q'~return get_time();~',
            p_json_schema => C_INPUT_SCHEMA,
            p_tags => apex_t_varchar2('ext-apps')
        );
        /* create default UI resource, text should be updated later */
        merge into oj_mcp_ui_resources t
        using (
            select
                l_app                                name,
                'ui://' || l_app || '/mcp-app.html'  uri,
                'text/html;profile=mcp-app'          mime_type,
                'Returns the current server time as an ISO 8601 string.' description,
                C_DEFAULT_HTML                       text
            from dual
        ) s
        on (t.name = s.name)
        when matched then
            update set
                t.uri         = s.uri,
                t.mime_type   = s.mime_type,
                t.description = s.description,
                t.text        = case when t.text is null then s.text else t.text end,
                t.updated_by  = l_update_user,
                t.updated_at  = l_update_time
        when not matched then
            insert (name, uri, mime_type, description, text, created_by, created_at, updated_by, updated_at)
            values (s.name, s.uri, s.mime_type, s.description, s.text, l_update_user, l_update_time, l_update_user, l_update_time)
        ;
        /* register ui resource to the tool */
        select id into l_tool_id from uc_ai_tools where code = l_app;
        select id into l_resource_id from oj_mcp_ui_resources where name = l_app;
        merge into oj_mcp_tools_extras t
        using (
            select l_tool_id tool_id, l_resource_id resource_id from dual
        ) s
        on (t.tool_id = s.tool_id)
        when matched then
            update set
                t.resource_id = s.resource_id,
                t.output_schema = C_OUTPUT_SCHEMA
        when not matched then
            insert (tool_id, resource_id, output_schema) values(s.tool_id, s.resource_id, C_OUTPUT_SCHEMA)
        ;
    end loop;
    commit;
end;
/