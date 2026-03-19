set serveroutput on
begin
    sys.dbms_xs_sessions.destroy_session(
        sessionid => hextoraw('&SESSIONID'),
        force => true
    );
end;
/
