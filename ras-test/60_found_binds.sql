set serveroutput on
declare
    l_found_binds apex_t_varchar2 := apex_t_varchar2();
    l_string varchar2(4000);
begin
    l_string := '&STRING'; 
    l_found_binds := apex_string.grep(
        p_str           => l_string
        , p_pattern       => ':([a-zA-Z0-9:\_]+)'
        , p_modifier      => 'i'
        , p_subexpression => '1'
    );
    if l_found_binds is not null then
        for i in 1..l_found_binds.count
        loop
            dbms_output.put_line(l_found_binds(i));
        end loop;
    end if;
end;
/
