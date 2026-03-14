set serveroutput on
/*
 * Delete ORDS REST Module sampleserver if exists.
 */
declare
    l_exist pls_integer;
begin
    select 1 into l_exist from user_ords_modules
    where name = 'sampleserver';
    ords.delete_module( p_module_name => 'sampleserver');
    dbms_output.put_line('ORDS REST module sampleserver deleted');
exception
    when no_data_found then
        /* not exist */
        null;
end;
/

/*
 * Drop packages.
 */
declare
    type t_command_table is table of varchar2(100);
    l_drop varchar2(100);
    l_drop_cmds t_command_table := t_command_table(
        'drop package oj_mcp_app_server',
        'drop package oj_mcp_app_methods',
        'drop package oj_mcp_app_utils',
        'drop package oj_mcp_jsonrpc_utils',
        'drop view oj_mcp_uc_ai_tools',
        'drop table oj_mcp_tools_extras',
        'drop table oj_mcp_ui_permissions',
        'drop table oj_mcp_ui_csp_domains',
        'drop table oj_mcp_ui_resources'
    );
    e_obj_not_exist EXCEPTION;
    e_tbl_not_exist EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_obj_not_exist, -4043);
    PRAGMA EXCEPTION_INIT(e_tbl_not_exist, -942);
begin
    for i in 1 .. l_drop_cmds.count
    loop
        begin
            l_drop := l_drop_cmds(i);
            execute immediate l_drop;
            dbms_output.put_line('Completed: ' || l_drop);
        exception
            when e_obj_not_exist then
                /* not exist */
                null;
            when e_tbl_not_exist then
                /* not exist */
                null;
        end;
    end loop;
end;
/
