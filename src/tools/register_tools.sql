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

/**
 * Register function run_sql as a UC_AI tool.
 */
declare
  l_schema  json_object_t;
  l_tool_id uc_ai_tools.id%type;
begin
  l_schema := json_object_t.parse('
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "run_sql",
  "description": "Run SQL SELECT statement on Oracle Database and return the result in JSON document.",
  "properties": {
    "sql": {
      "type": "string",
      "description": "SELECT statement to run on Oracle Database."
    }
  },
  "required": [
    "sql"
  ]
}');
    -- Create the tool
  l_tool_id := uc_ai_tools_api.create_tool_from_schema(
    p_tool_code => 'run_sql',
    p_description => 'Run SQL SELECT statement on Oracle Database and return the result in JSON document.',
    p_function_call => 'return #SESSION_USER#.run_sql(:parameters);',
    p_json_schema => l_schema,
    p_tags => apex_t_varchar2('nl2sql','sampleserver','run-sql')
  );
  commit;
end;
/


/**
 * Register function get_schema as a UC_AI tool.
 */
declare
  l_schema  json_object_t;
  l_tool_id uc_ai_tools.id%type;
begin
  l_schema := json_object_t.parse('
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "get_schema",
  "description": "return a list of tables and columns and its types that the schema contains .",
  "properties": {
    "schema": {
      "type": "string",
      "description": "Schema name to describe the information but it is not usually necessary."
    }
  }
}');
    -- Create the tool
  l_tool_id := uc_ai_tools_api.create_tool_from_schema(
    p_tool_code => 'get_schema',
    p_description => 'return a list of tables and columns and its types that the schema contains .',
    p_function_call => 'return get_schema(:parameters);',
    p_json_schema => l_schema,
    p_tags => apex_t_varchar2('nl2sql','sampleserver')
  );
  commit;
end;
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
  "title": "get_authenticated_identity",
  "description": "Get current sign-in username."
}');
    -- Create the tool
  l_tool_id := uc_ai_tools_api.create_tool_from_schema(
    p_tool_code => 'get_authenticated_identity',
    p_description => 'Get current sign-in username.',
    p_function_call => 'return ''{ "username": #AUTHENTICATED_IDENTITY# }'';',
    p_json_schema => l_schema,
    p_tags => apex_t_varchar2('sampleserver','run-sql')
  );
  commit;
end;
/
