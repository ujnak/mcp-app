set serveroutput on
declare
   l_sql varchar2(1000);
   l_out clob;
   l_param clob;
begin
   l_param := 'select * from dual';
   l_sql := 'return run_sql(:parameters); end;';
   execute immediate l_sql using out l_out, in l_param;
   dbms_output.put_line(l_out);
end; 
/
