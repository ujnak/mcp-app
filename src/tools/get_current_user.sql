/**
 * get current Username.
 */
create or replace function get_current_user
return clob
as
    l_username varchar2(400);
    l_result   clob;
begin
    select sys_context('APEX$SESSION','APP_USER') into l_username from dual;
    if l_username = null then
        l_result := '{ "result": "no username found. MCP server is not protected." }';
    else
        l_result := apex_string.format('{ "username": "%s" }', l_username);
    end if;
    return l_result;
end get_current_user;
/ 

/**
 * Register function get_current_user as a UC_AI tool.
 */
declare
  l_schema  json_object_t;
  l_tool_id uc_ai_tools.id%type;
begin
  l_schema := json_object_t.parse('
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "get_current_user",
  "description": "Get current sign-in username."
}');
    -- Create the tool
  l_tool_id := uc_ai_tools_api.create_tool_from_schema(
    p_tool_code => 'get_current_user',
    p_description => 'Get current sign-in username.',
    p_function_call => 'return get_current_user;',
    p_json_schema => l_schema,
    p_tags => apex_t_varchar2('nl2sql','sampleserver')
  );
  commit;
end;
/
