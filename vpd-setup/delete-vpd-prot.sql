
set serveroutput on
set echo on

begin
    dbms_rls.drop_policy(
        object_schema => 'hr'
        ,object_name => 'employees'
        ,policy_name => 'employee_in_same_department'
    );
    dbms_rls.drop_policy(
        object_schema => 'hr'
        ,object_name => 'employees'
        ,policy_name => 'employee_is_manager'
    );
end;
/

drop function pred_employee_in_same_department;
drop function pred_employee_is_manager;

drop package oj_mcp_vpd_config;
-- drop context emp_dept_ctx;