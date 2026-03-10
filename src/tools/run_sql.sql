/**
 * Execute an arbitrary SELECT statement.
 */
create or replace function run_sql(
    p_args in clob
)
return clob
as
    C_STMT constant varchar2(4000) :=     q'~select json_arrayagg(object returning clob) from (
        select json_object(*) object from (
            %s
        )
    )~';
    l_stmt   clob;
    l_result clob;
    l_args json_object_t;
    l_sql  varchar2(32767);
begin
    l_args := json_object_t(p_args);
    l_sql := trim(l_args.get_string('sql'));
    /* remove trailing ; from the sql */
    l_sql := rtrim(l_sql, ';');
    l_stmt := apex_string.format(C_STMT, l_sql);
    execute immediate l_stmt into l_result;
    if l_result is null then
        l_result := '{ "result": "no data found, please consider to change the condition supplied with this select statment." }';
    end if;
    if dbms_lob.getlength(l_result) > 8192 then
        l_result := '{ "result": "The output is excessively large. Please apply more detailed constraints within the prompt." }';
    end if;
    return l_result;
end run_sql;
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
    p_function_call => 'return run_sql(:parameters);',
    p_json_schema => l_schema,
    p_tags => apex_t_varchar2('nl2sql','sampleserver')
  );
  commit;
end;
/
