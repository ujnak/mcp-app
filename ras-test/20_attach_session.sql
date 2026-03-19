set serveroutput on
begin
    sys.dbms_xs_sessions.attach_session(
        sessionid => hextoraw('&SESSIONID'),
        enable_dynamic_roles => xs$name_list('EMPLOYEE','MCPRUNTIME')
    );
end;
/
