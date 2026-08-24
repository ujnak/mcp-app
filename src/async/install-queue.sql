declare
    l_schema varchar2(128) := upper(sys_context('USERENV', 'CURRENT_SCHEMA'));
    l_subscriber sys.aq$_agent;
begin
    execute immediate
        'create type oj_mcp_task_message_t as object (task_id varchar2(64 char))';

    dbms_aqadm.create_queue_table(
        queue_table        => 'OJ_MCP_TASK_QTAB',
        queue_payload_type => l_schema || '.OJ_MCP_TASK_MESSAGE_T',
        multiple_consumers => true
    );

    dbms_aqadm.create_queue(
        queue_name  => 'OJ_MCP_TASK_Q',
        queue_table => 'OJ_MCP_TASK_QTAB'
    );

    dbms_aqadm.start_queue(queue_name => 'OJ_MCP_TASK_Q');

    l_subscriber := sys.aq$_agent(l_schema, null, null);
    dbms_aqadm.add_subscriber(
        queue_name => l_schema || '.OJ_MCP_TASK_Q',
        subscriber => l_subscriber
    );
end;
/
