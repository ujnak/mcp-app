create or replace package test_oj_mcp_tasks as

    --%suite(MCP Tasks extension)
    --%rollback(manual)

    --%aftereach
    procedure cleanup_task;

    --%test(Recognizes per-request Tasks capability)
    procedure recognizes_capability;

    --%test(Executes run_sql as a durable asynchronous task)
    procedure run_sql_task_lifecycle;

    --%test(Acknowledges cancellation and exposes cancelled state)
    procedure cancel_task;

end test_oj_mcp_tasks;
/

create or replace package body test_oj_mcp_tasks as

g_task_id varchar2(64);

procedure cleanup_task
is
begin
    if g_task_id is not null then
        delete from oj_mcp_task_states where task_id = g_task_id;
        commit;
        g_task_id := null;
    end if;
end cleanup_task;

procedure recognizes_capability
is
    l_capabilities json_object_t;
begin
    l_capabilities := json_object_t.parse(
        '{"extensions":{"io.modelcontextprotocol/tasks":{}}}'
    );
    ut.expect(oj_mcp_tasks.client_supports_tasks(l_capabilities)).to_be_true();
    ut.expect(oj_mcp_tasks.client_supports_tasks(json_object_t())).to_be_false();
end recognizes_capability;

procedure run_sql_task_lifecycle
is
    l_args json_object_t := json_object_t();
    l_created json_object_t;
    l_params json_object_t := json_object_t();
    l_task json_object_t;
    l_tool_result json_object_t;
    l_content json_array_t;
    l_rows json_array_t;
    l_row json_object_t;
    l_result clob;
    l_error clob;
    l_status_code number;
    l_ords_pattern user_ords_schemas.pattern%type;
    l_app_id apex_applications.application_id%type;
    l_page_id apex_application_pages.page_id%type;
begin
    select pattern
      into l_ords_pattern
      from user_ords_schemas
     fetch first 1 row only;

    select application_id
      into l_app_id
      from apex_applications
     where workspace = upper(l_ords_pattern)
       and alias = 'SAMPLESERVER';

    select min(page_id)
      into l_page_id
      from apex_application_pages
     where application_id = l_app_id
       and page_id > 0;

    l_args.put('sql', 'select * from dual');
    l_created := oj_mcp_tasks.create_tool_task(
        p_tool_name        => 'run_sql',
        p_arguments        => l_args,
        p_current_user     => sys_context('USERENV', 'CURRENT_USER'),
        p_ords_pattern     => l_ords_pattern,
        p_ords_module_name => 'sampleserver',
        p_apex_app_id      => l_app_id,
        p_apex_page_id     => l_page_id
    );
    g_task_id := l_created.get_string('taskId');

    ut.expect(l_created.get_string('resultType')).to_equal('task');
    ut.expect(g_task_id).not_to_be_null();

    l_params.put('taskId', g_task_id);
    for i in 1 .. 40 loop
        oj_mcp_tasks.get_task(
            l_params.to_clob(),
            sys_context('USERENV', 'CURRENT_USER'),
            l_result,
            l_error,
            l_status_code
        );
        l_task := json_object_t.parse(l_result);
        exit when l_task.get_string('status') in ('completed', 'failed', 'cancelled');
        dbms_session.sleep(0.25);
    end loop;

    ut.expect(l_status_code).to_equal(200);
    ut.expect(l_error).to_be_null();
    ut.expect(l_task.get_string('resultType')).to_equal('complete');
    ut.expect(l_task.get_string('status')).to_equal('completed');

    l_tool_result := l_task.get_object('result');
    l_content := l_tool_result.get_array('content');
    l_rows := json_array_t.parse(
        treat(l_content.get(0) as json_object_t).get_string('text')
    );
    l_row := treat(l_rows.get(0) as json_object_t);
    ut.expect(l_row.get_string('DUMMY')).to_equal('X');
end run_sql_task_lifecycle;

procedure cancel_task
is
    l_now timestamp with time zone := systimestamp;
    l_params json_object_t := json_object_t();
    l_task json_object_t;
    l_result clob;
    l_error clob;
    l_status_code number;
begin
    g_task_id := lower(rawtohex(sys_guid()));
    insert into oj_mcp_task_states(
        task_id, owner_name, execution_schema, tool_name, status, status_message,
        created_at, last_updated_at, ttl_ms, poll_interval_ms,
        cancel_requested, ords_pattern, ords_module_name,
        apex_app_id, apex_page_id
    ) values (
        g_task_id, sys_context('USERENV', 'CURRENT_USER'),
        sys_context('USERENV', 'CURRENT_SCHEMA'), '__ut_cancel__',
        'working', 'Unit test task.', l_now, l_now, 60000, 1000,
        0, 'UT', 'UT', 1, 1
    );
    commit;

    l_params.put('taskId', g_task_id);
    oj_mcp_tasks.cancel_task(
        l_params.to_clob(),
        sys_context('USERENV', 'CURRENT_USER'),
        l_result,
        l_error,
        l_status_code
    );

    ut.expect(l_status_code).to_equal(200);
    ut.expect(l_error).to_be_null();
    ut.expect(json_object_t.parse(l_result).get_size()).to_equal(0);

    oj_mcp_tasks.get_task(
        l_params.to_clob(),
        sys_context('USERENV', 'CURRENT_USER'),
        l_result,
        l_error,
        l_status_code
    );
    l_task := json_object_t.parse(l_result);
    ut.expect(l_task.get_string('status')).to_equal('cancelled');
end cancel_task;

end test_oj_mcp_tasks;
/

begin
    ut.run('test_oj_mcp_tasks');
end;
/
