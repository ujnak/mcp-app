set serveroutput on
set echo on

-- dynamic role EMPLOYEE to access schema HR.
begin
    sys.xs_principal.create_dynamic_role(
        name => 'EMPLOYEE',
        scope => XS_PRINCIPAL.SESSION_SCOPE
    );
end;
/
grant hr_role to employee;

-- dynamic role MCPRUNTIME to access MCP server framework.
begin
    sys.xs_principal.create_dynamic_role(
        name => 'MCPRUNTIME',
        scope => XS_PRINCIPAL.SESSION_SCOPE
    );
end;
/
grant mcp_role to mcpruntime;

-- namespace template HREMP which refered by ACL
declare
    attrlist XS$NS_ATTRIBUTE_LIST;
begin
    attrlist := XS$NS_ATTRIBUTE_LIST();
    attrlist.extend(2);
    attrlist(1) := XS$NS_ATTRIBUTE('employee_id','0');
    attrlist(2) := XS$NS_ATTRIBUTE('department_id','0');
    sys.xs_namespace.create_template(
        name => 'HREMP',
        attr_list => attrlist,
        acl => 'SYS.NS_UNRESTRICTED_ACL'
    );
end;
/

-- security class emp_priv
begin
    sys.xs_security_class.create_security_class(
        name => 'emp_priv',
        parent_list => xs$name_list('sys.dml'),
        priv_list => xs$privilege_list(xs$privilege('view_sal'))
    );
end;
/

-- ACL: emp_acl - Restrict access to the same department as the signed-in user.
declare
    aces xs$ace_list := xs$ace_list();
begin
    aces.extend(1);
    aces(1) := xs$ace_type(
        privilege_list => xs$name_list('select','insert','update','delete'),
        principal_name => 'employee' -- application role
    );
    sys.xs_acl.create_acl(
        name => 'emp_acl',
        ace_list => aces,
        sec_class => 'emp_priv' -- security class
    );
end;
/

-- ACL: mgr_acl - Restrict access to the SALARY and COMMISSION_PCT columns
--                for employees whose manager is the signed-in user.
declare
    aces xs$ace_list := xs$ace_list();
begin
    aces.extend(1);
    aces(1) := xs$ace_type(
        privilege_list => xs$name_list('select','insert','update','delete','view_sal'),
        principal_name => 'employee' -- application role
    );
    sys.xs_acl.create_acl(
        name => 'mgr_acl',
        ace_list => aces,
        sec_class => 'emp_priv'
    );
end;
/

-- data security policy employees_ds that includes ACL emp_acl and mgr_acl
declare
    realms xs$realm_constraint_list := xs$realm_constraint_list();
    cols xs$column_constraint_list := xs$column_constraint_list();
begin
    realms.extend(2);
    realms(1) := xs$realm_constraint_type(
        realm => q'~department_id = xs_sys_context('HREMP','department_id')~',
        acl_list => xs$name_list('emp_acl')
    );
    realms(2) := xs$realm_constraint_type(
        realm => q'~manager_id = xs_sys_context('HREMP','employee_id')~',
        acl_list => xs$name_list('mgr_acl')
    );
    cols.extend(1);
    cols(1) := xs$column_constraint_type(
        column_list => xs$list('SALARY','COMMISSION_PCT'),
        privilege => 'view_sal'
    );
    sys.xs_data_security.create_policy(
        name => 'employee_ds',
        realm_constraint_list => realms,
        column_constraint_list => cols
    );
end;
/

-- apply data security policy employees_ds to hr.employees
begin
    sys.xs_data_security.apply_object_policy(
        policy => 'employee_ds',
        schema => 'hr',
        object => 'employees'
    );
end;
/

-- verify configuration
begin
    if (sys.xs_diag.validate_workspace()) then
        dbms_output.put_line('All Configurations are correct.');
    else
        dbms_output.put_line('Some configurations are incorrect.');
    end if;
end;
/
