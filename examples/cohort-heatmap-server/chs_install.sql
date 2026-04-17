set serveroutput on
-- create tables
@@chs_create_tables.sql
-- procedure to generate sample data.
@@chs_generate_cohort_data.sql
-- function to generate the response for tools call.
@@chs_get_cohort_data_response.sql
-- insert configuration data (RetentionParams per metric)
@@chs_prepare_metric_params.sql
--
begin
    chs_generate_cohort_data;
end;
/
commit;
-- generate tools call response
begin
    dbms_output.put_line(chs_get_cohort_data_response);
end;
/
exit;
