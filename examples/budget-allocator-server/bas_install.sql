set serveroutput on
-- create tables
@@bas_create_tables.sql
-- procedure to generate sample data.
@@bas_generate_history.sql
-- function to generate the response for tools call.
@@bas_get_budget_data_response.sql
-- insert test data 
@@bas_prepare_budget_categories.sql
@@bas_prepare_budget_config.sql
--
begin
    bas_generate_history;
end;
/
--
@@bas_prepare_budget_analytics.sql
commit;
-- generate tools call response
begin
    dbms_output.put_line(bas_get_budget_data_response);
end;
/
exit;
