set serveroutput on
declare
    l_sessionid raw(16);
    l_nsattrlist sys.dbms_xs_nsattrlist;
    l_cookie varchar2(1024);
begin
    l_nsattrlist := sys.dbms_xs_nsattrlist();
    l_nsattrlist.extend(2);
    l_nsattrlist(1) := sys.dbms_xs_nsattr('HREMP', 'employee_id', 105);
    l_nsattrlist(2) := sys.dbms_xs_nsattr('HREMP', 'department_id', 60);
    dbms_output.put_line('employee_id: ' || l_nsattrlist(1).attribute_value || ' department_id: ' || l_nsattrlist(2).attribute_value);
    l_cookie := sys_guid();
    sys.dbms_xs_sessions.create_session(
        username => 'mymymy',
        sessionid => l_sessionid,
        is_external => true,
        cookie      => l_cookie,
        namespaces => l_nsattrlist
    );
    dbms_output.put_line('session id: ' || l_sessionid);
    /*
    sys.dbms_xs_sessions.attach_session(
        sessionid => l_sessionid,
        enable_dynamic_roles => xs$name_list('EMPLOYEE')
    );
    */
end;
/

