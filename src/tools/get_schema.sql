/**
 * Return the specified schema information as a JSON document.
 */
create or replace function get_schema(
    p_args in clob
)
return clob
as
    l_owner_object json_object_t;
    l_owner varchar2(128);
    l_schema clob;
begin
    l_owner_object := json_object_t(p_args);
    l_owner := l_owner_object.get_string('schema');
    if l_owner is null then
        /* set default owner */
        l_owner := SYS_CONTEXT('USERENV', 'CURRENT_USER');
    else
        l_owner := upper(l_owner);
    end if;
    select json_arrayagg(objects returning clob) into l_schema from (
        select json_object(table_name, columns) objects from (
            select table_name, json_arrayagg(json_object(column_name, data_type)) columns 
            from all_tab_columns where owner = l_owner group by table_name
        )
    );
    return l_schema;
end get_schema;
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