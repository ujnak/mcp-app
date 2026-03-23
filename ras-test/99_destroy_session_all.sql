set serveroutput on
begin
    for r in (
        select sessionid from dba_xs_sessions
    )
    loop
        sys.dbms_xs_sessions.destroy_session(
            sessionid => r.sessionid,
            force => true
        );
    end loop;
end;
/
