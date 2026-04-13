set serveroutput on
set echo on

/*
 * create context emp_dept_ctx
 */
create or replace context emp_dept_ctx using oj_mcp_vpd_config;
-- create a package to manage context.
@@../src/vpd/oj_mcp_vpd_config.pks
@@../src/vpd/oj_mcp_vpd_config.pkb
-- 
grant execute on oj_mcp_vpd_config to &SCHEMA;

/*
 * Create policy functions.
 */
@@../src/vpd/pred_employee_in_same_department.pls 
@@../src/vpd/pred_employee_is_manager.pls

/*
 * Create and apply VPD policy.
 */
begin
    dbms_rls.add_policy(
        object_schema => 'hr'
      , object_name => 'employees'
      , policy_name => 'employee_is_manager'
      , function_schema => 'vpdadmin'
      , policy_function => 'pred_employee_is_manager'
      , statement_types => 'select'
      , policy_type => DBMS_RLS.CONTEXT_SENSITIVE
      , sec_relevant_cols => 'salary,commission_pct'
      , sec_relevant_cols_opt => DBMS_RLS.ALL_ROWS
      , namespace => 'emp_dept_ctx'
      , attribute => 'employee_id'
    );
end;
/

begin
    dbms_rls.add_policy(
        object_schema => 'hr'
      , object_name => 'employees'
      , policy_name => 'employee_in_same_department'
      , function_schema => 'vpdadmin'
      , policy_function => 'pred_employee_in_same_department'
      , statement_types => 'select'
      , policy_type => DBMS_RLS.CONTEXT_SENSITIVE
      , namespace => 'emp_dept_ctx'
      , attribute => 'department_id'
    );
end;
/