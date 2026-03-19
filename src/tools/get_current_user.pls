create or replace function get_current_user
return clob
authid current_user
/**
 * get current Username.
 */
as
    l_username varchar2(400);
    l_result   clob;
begin
    select sys_context('APEX$SESSION','APP_USER') into l_username from dual;
    if l_username = null then
        l_result := '{ "result": "no username found. MCP server is not protected." }';
    else
        l_result := apex_string.format('{ "username": "%s" }', l_username);
    end if;
    return l_result;
end get_current_user;
/ 
