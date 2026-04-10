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