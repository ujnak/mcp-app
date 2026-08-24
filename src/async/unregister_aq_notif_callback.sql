declare
    l_schema varchar2(128) := upper(sys_context('USERENV', 'CURRENT_SCHEMA'));
    l_registration sys.aq$_reg_info;
    l_registrations sys.aq$_reg_info_list;
begin
    l_registration := sys.aq$_reg_info(
        l_schema || '.OJ_MCP_TASK_Q:' || l_schema,
        dbms_aq.namespace_aq,
        'plsql://' || l_schema || '.OJ_MCP_TASK_WORKER',
        hextoraw('FF')
    );
    l_registrations := sys.aq$_reg_info_list(l_registration);
    dbms_aq.unregister(l_registrations, 1);
end;
/
