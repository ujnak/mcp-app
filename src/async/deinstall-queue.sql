declare
    l_schema varchar2(128) := upper(sys_context('USERENV', 'CURRENT_SCHEMA'));
    l_subscriber sys.aq$_agent;
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
    begin
        dbms_aq.unregister(l_registrations, 1);
    exception when others then null;
    end;

    l_subscriber := sys.aq$_agent(l_schema, null, null);
    begin
        dbms_aqadm.remove_subscriber(
            queue_name => l_schema || '.OJ_MCP_TASK_Q',
            subscriber => l_subscriber
        );
    exception when others then null;
    end;

    begin
        dbms_aqadm.stop_queue(queue_name => 'OJ_MCP_TASK_Q');
    exception when others then null;
    end;

    begin
        dbms_aqadm.drop_queue(queue_name => 'OJ_MCP_TASK_Q');
    exception when others then null;
    end;

    begin
        dbms_aqadm.drop_queue_table(queue_table => 'OJ_MCP_TASK_QTAB', force => true);
    exception when others then null;
    end;

    begin
        execute immediate 'drop type oj_mcp_task_message_t force';
    exception when others then null;
    end;

    /* Remove the superseded pre-2026-07-28 experimental AQ objects. */
    l_registration := sys.aq$_reg_info(
        l_schema || '.OJ_MCP_TOOLS_IN_Q:' || l_schema,
        dbms_aq.namespace_aq,
        'plsql://' || lower(l_schema) || '.tools_call_async',
        hextoraw('FF')
    );
    l_registrations := sys.aq$_reg_info_list(l_registration);
    begin
        dbms_aq.unregister(l_registrations, 1);
    exception when others then null;
    end;

    begin
        dbms_aqadm.remove_subscriber(
            queue_name => l_schema || '.OJ_MCP_TOOLS_IN_Q',
            subscriber => l_subscriber
        );
    exception when others then null;
    end;

    begin
        dbms_aqadm.remove_subscriber(
            queue_name => l_schema || '.OJ_MCP_TOOLS_OUT_Q',
            subscriber => l_subscriber
        );
    exception when others then null;
    end;

    begin
        dbms_aqadm.stop_queue(queue_name => 'OJ_MCP_TOOLS_IN_Q');
    exception when others then null;
    end;

    begin
        dbms_aqadm.stop_queue(queue_name => 'OJ_MCP_TOOLS_OUT_Q');
    exception when others then null;
    end;

    begin
        dbms_aqadm.drop_queue(queue_name => 'OJ_MCP_TOOLS_IN_Q');
    exception when others then null;
    end;

    begin
        dbms_aqadm.drop_queue(queue_name => 'OJ_MCP_TOOLS_OUT_Q');
    exception when others then null;
    end;

    begin
        dbms_aqadm.drop_queue_table(queue_table => 'OJ_MCP_TOOLS_Q_TAB', force => true);
    exception when others then null;
    end;

    begin
        execute immediate 'drop type oj_mcp_tools_message_t force';
    exception when others then null;
    end;
end;
/
