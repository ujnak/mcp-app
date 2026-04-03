set serveroutput on
set echo on

begin
    sys.xs_data_security.remove_object_policy(
        policy => 'employee_ds'
      , schema => 'hr'
      , object => 'employees'
    );
end;
/

begin
    sys.xs_data_security.delete_policy(
        policy => 'employee_ds'
      , delete_option => xs_admin_util.cascade_option
    );
end;
/

begin
    sys.xs_acl.delete_acl(
        acl => 'emp_acl' 
      , delete_option => xs_admin_util.cascade_option
    );
    sys.xs_acl.delete_acl(
        acl => 'mgr_acl' 
      , delete_option => xs_admin_util.cascade_option
    );
end;
/

begin
    sys.xs_security_class.delete_security_class(
        sec_class => 'emp_priv'
      , delete_option => xs_admin_util.cascade_option
    );
end;
/

begin
   sys.xs_namespace.delete_template(
       template => 'HREMP'
   );
end;
/

begin
   sys.xs_principal.delete_principal(
       principal => 'MCPRUNTIME'
   );
end;
/

begin
   sys.xs_principal.delete_principal(
       principal => 'EMPLOYEE'
   );
end;
/

begin
    if (sys.xs_diag.validate_workspace()) then
        dbms_output.put_line('All Configurations are correct.');
    else
        dbms_output.put_line('Some configurations are incorrect.');
    end if;
end;
/
