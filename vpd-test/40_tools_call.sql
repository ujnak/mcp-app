set serveroutput on
declare
    l_params clob;
    l_out    clob;
begin
    l_params := '{ "sql": "select * from hr.employees" }';
    l_out := "WKSP_APEXDEV".run_sql(l_params);
    dbms_output.put_line(l_out); 
end;
/
