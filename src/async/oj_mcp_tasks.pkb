create or replace package body oj_mcp_tasks
as

gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

C_INVALID_PARAMS constant number := -32602;
C_INTERNAL_ERROR constant number := -32603;

function client_supports_tasks(
    p_client_capabilities in json_object_t
) return boolean
as
    l_extensions json_object_t;
begin
    if p_client_capabilities is null then
        return false;
    end if;

    l_extensions := p_client_capabilities.get_object('extensions');
    return l_extensions is not null
       and l_extensions.get_object(C_EXTENSION_ID) is not null;
exception
    when others then
        return false;
end client_supports_tasks;

function tool_tasks_enabled(
    p_tool_name in varchar2
) return boolean
as
    l_enabled number;
begin
    select nvl(task_enabled, 0)
      into l_enabled
      from oj_mcp_uc_ai_tools
     where code = p_tool_name;

    return l_enabled = 1;
exception
    when no_data_found then
        return false;
end tool_tasks_enabled;

function iso_timestamp(
    p_timestamp in timestamp with time zone
) return varchar2
as
begin
    return to_char(
        sys_extract_utc(p_timestamp),
        'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'
    );
end iso_timestamp;

function task_to_json(
    p_task        in oj_mcp_task_states%rowtype,
    p_result_type in varchar2
) return json_object_t
as
    l_result json_object_t := json_object_t();
begin
    l_result.put('resultType', p_result_type);
    l_result.put('taskId', p_task.task_id);
    l_result.put('status', p_task.status);
    if p_task.status_message is not null then
        l_result.put('statusMessage', p_task.status_message);
    end if;
    l_result.put('createdAt', iso_timestamp(p_task.created_at));
    l_result.put('lastUpdatedAt', iso_timestamp(p_task.last_updated_at));
    if p_task.ttl_ms is null then
        l_result.put_null('ttlMs');
    else
        l_result.put('ttlMs', p_task.ttl_ms);
    end if;
    if p_task.poll_interval_ms is not null then
        l_result.put('pollIntervalMs', p_task.poll_interval_ms);
    end if;

    if p_task.status = 'completed' and p_task.result_json is not null then
        l_result.put('result', json_object_t.parse(p_task.result_json));
    elsif p_task.status = 'failed' and p_task.error_json is not null then
        l_result.put('error', json_object_t.parse(p_task.error_json));
    end if;

    return l_result;
end task_to_json;

function error_json(
    p_code    in number,
    p_message in varchar2
) return clob
as
    l_error json_object_t := json_object_t();
begin
    l_error.put('code', p_code);
    l_error.put('message', p_message);
    return l_error.to_clob();
end error_json;

function task_is_expired(
    p_task in oj_mcp_task_states%rowtype
) return boolean
as
begin
    return p_task.ttl_ms is not null
       and systimestamp > p_task.created_at
           + numtodsinterval(p_task.ttl_ms / 1000, 'SECOND');
end task_is_expired;

function create_tool_task(
    p_tool_name        in varchar2,
    p_arguments        in json_object_t,
    p_current_user     in varchar2,
    p_ords_pattern     in varchar2,
    p_ords_module_name in varchar2,
    p_apex_app_id      in number,
    p_apex_page_id     in number,
    p_ras_config_pkg   in varchar2 default null
) return json_object_t
as
    pragma autonomous_transaction;

    l_task_id varchar2(64) := lower(rawtohex(sys.dbms_crypto.randombytes(32)));
    l_now timestamp with time zone := systimestamp;
    l_arguments clob;
    l_ttl_ms number;
    l_poll_interval_ms number;
    l_task oj_mcp_task_states%rowtype;
    l_enqueue_options dbms_aq.enqueue_options_t;
    l_message_properties dbms_aq.message_properties_t;
    l_message_handle raw(16);
    l_message oj_mcp_task_message_t;
begin
    select task_ttl_ms, task_poll_interval_ms
      into l_ttl_ms, l_poll_interval_ms
      from oj_mcp_uc_ai_tools
     where code = p_tool_name
       and task_enabled = 1;

    if p_arguments is not null then
        l_arguments := p_arguments.to_clob();
    end if;

    insert into oj_mcp_task_states(
        task_id, owner_name, execution_schema, tool_name, arguments_json, status,
        status_message, created_at, last_updated_at, ttl_ms,
        poll_interval_ms, cancel_requested, ords_pattern,
        ords_module_name, apex_app_id, apex_page_id, ras_config_pkg
    ) values (
        l_task_id, p_current_user,
        upper(sys_context('USERENV', 'CURRENT_SCHEMA')),
        p_tool_name, l_arguments, 'working',
        'Tool execution has been queued.', l_now, l_now, l_ttl_ms,
        l_poll_interval_ms, 0, p_ords_pattern,
        p_ords_module_name, p_apex_app_id, p_apex_page_id, p_ras_config_pkg
    );

    l_message := oj_mcp_task_message_t(l_task_id);
    l_message_properties.correlation := l_task_id;
    dbms_aq.enqueue(
        queue_name          => 'OJ_MCP_TASK_Q',
        enqueue_options     => l_enqueue_options,
        message_properties  => l_message_properties,
        payload             => l_message,
        msgid               => l_message_handle
    );

    update oj_mcp_task_states
       set aq_msgid = l_message_handle
     where task_id = l_task_id;

    select * into l_task
      from oj_mcp_task_states
     where task_id = l_task_id;

    commit;
    return task_to_json(l_task, 'task');
exception
    when others then
        rollback;
        raise;
end create_tool_task;

procedure get_task(
    p_params       in clob,
    p_current_user in varchar2,
    p_result       out clob,
    p_error        out clob,
    p_status_code  out number
)
as
    l_params json_object_t;
    l_task_id varchar2(64);
    l_task oj_mcp_task_states%rowtype;
begin
    l_params := json_object_t.parse(p_params);
    l_task_id := l_params.get_string('taskId');
    if l_task_id is null then
        p_error := error_json(C_INVALID_PARAMS, 'Invalid parameters: taskId is required');
        p_result := null;
        p_status_code := 400;
        return;
    end if;

    begin
        select * into l_task
          from oj_mcp_task_states
         where task_id = l_task_id
           and owner_name = p_current_user;
    exception
        when no_data_found then
            p_error := error_json(C_INVALID_PARAMS, 'Failed to retrieve task: Task not found');
            p_result := null;
            p_status_code := 400;
            return;
    end;

    if task_is_expired(l_task) then
        p_error := error_json(C_INVALID_PARAMS, 'Failed to retrieve task: Task has expired');
        p_result := null;
        p_status_code := 400;
        return;
    end if;

    p_result := task_to_json(l_task, 'complete').to_clob();
    p_error := null;
    p_status_code := 200;
exception
    when others then
        p_error := error_json(C_INTERNAL_ERROR, 'Failed to retrieve task: ' || sqlerrm);
        p_result := null;
        p_status_code := 500;
end get_task;

procedure update_task(
    p_params       in clob,
    p_current_user in varchar2,
    p_result       out clob,
    p_error        out clob,
    p_status_code  out number
)
as
    l_params json_object_t;
    l_task_id varchar2(64);
    l_input_responses json_object_t;
    l_count pls_integer;
begin
    l_params := json_object_t.parse(p_params);
    l_task_id := l_params.get_string('taskId');
    l_input_responses := l_params.get_object('inputResponses');
    if l_task_id is null or l_input_responses is null then
        p_error := error_json(
            C_INVALID_PARAMS,
            'Invalid parameters: taskId and inputResponses are required'
        );
        p_result := null;
        p_status_code := 400;
        return;
    end if;

    select count(*) into l_count
      from oj_mcp_task_states
     where task_id = l_task_id
       and owner_name = p_current_user;
    if l_count = 0 then
        p_error := error_json(C_INVALID_PARAMS, 'Failed to update task: Task not found');
        p_result := null;
        p_status_code := 400;
        return;
    end if;

    /* This implementation does not create input_required tasks. Unknown input
       response keys are ignored as permitted by the Tasks extension. */
    p_result := json_object_t().to_clob();
    p_error := null;
    p_status_code := 200;
exception
    when others then
        p_error := error_json(C_INTERNAL_ERROR, 'Failed to update task: ' || sqlerrm);
        p_result := null;
        p_status_code := 500;
end update_task;

procedure cancel_task(
    p_params       in clob,
    p_current_user in varchar2,
    p_result       out clob,
    p_error        out clob,
    p_status_code  out number
)
as
    pragma autonomous_transaction;

    l_params json_object_t;
    l_task_id varchar2(64);
    l_count pls_integer;
begin
    l_params := json_object_t.parse(p_params);
    l_task_id := l_params.get_string('taskId');
    if l_task_id is null then
        p_error := error_json(C_INVALID_PARAMS, 'Invalid parameters: taskId is required');
        p_result := null;
        p_status_code := 400;
        rollback;
        return;
    end if;

    select count(*) into l_count
      from oj_mcp_task_states
     where task_id = l_task_id
       and owner_name = p_current_user;
    if l_count = 0 then
        p_error := error_json(C_INVALID_PARAMS, 'Failed to cancel task: Task not found');
        p_result := null;
        p_status_code := 400;
        rollback;
        return;
    end if;

    update oj_mcp_task_states
       set cancel_requested = 1,
           status = case
               when status in ('working', 'input_required') then 'cancelled'
               else status
           end,
           status_message = case
               when status in ('working', 'input_required') then 'Cancellation requested.'
               else status_message
           end,
           last_updated_at = systimestamp
     where task_id = l_task_id
       and owner_name = p_current_user;

    commit;
    p_result := json_object_t().to_clob();
    p_error := null;
    p_status_code := 200;
exception
    when others then
        rollback;
        p_error := error_json(C_INTERNAL_ERROR, 'Failed to cancel task: ' || sqlerrm);
        p_result := null;
        p_status_code := 500;
end cancel_task;

procedure process_message(
    p_msgid         in raw,
    p_consumer_name in varchar2
)
as
    pragma autonomous_transaction;

    l_scope logger_logs.scope%type := gc_scope_prefix || 'process_message';
    l_dequeue_options dbms_aq.dequeue_options_t;
    l_message_properties dbms_aq.message_properties_t;
    l_message_handle raw(16);
    l_message oj_mcp_task_message_t;
    l_task oj_mcp_task_states%rowtype;
    l_arguments json_object_t;
    l_tool_result json_object_t;
    l_error json_object_t;
    l_result_clob clob;
    l_error_clob clob;
    l_failure_message varchar2(4000);
    l_apex_session_id varchar2(128);
    l_nsattrlist sys.dbms_xs_nsattrlist;
    l_apex_created boolean := false;
    l_ras_created boolean := false;
    e_no_messages exception;
    e_no_message_id exception;
    pragma exception_init(e_no_messages, -25228);
    pragma exception_init(e_no_message_id, -25263);

    procedure cleanup_context is
    begin
        if l_ras_created then
            begin
                oj_mcp_ras_ctx.destroy_session(l_task.owner_name, l_apex_session_id);
            exception when others then
                logger.log_error('Failed to destroy task RAS session: ' || sqlerrm, l_scope);
            end;
            l_ras_created := false;
        end if;
        if l_apex_created then
            begin
                apex_session.detach;
                apex_session.delete_session(l_apex_session_id);
            exception when others then
                logger.log_error('Failed to destroy task APEX session: ' || sqlerrm, l_scope);
            end;
            l_apex_created := false;
        end if;
    end cleanup_context;
begin
    l_dequeue_options.navigation := dbms_aq.first_message;
    l_dequeue_options.consumer_name := nvl(
        p_consumer_name,
        upper(sys_context('USERENV', 'CURRENT_SCHEMA'))
    );
    l_dequeue_options.wait := dbms_aq.no_wait;
    l_dequeue_options.dequeue_mode := dbms_aq.remove;
    if p_msgid is not null then
        l_dequeue_options.msgid := p_msgid;
    end if;

    begin
        dbms_aq.dequeue(
            queue_name         => 'OJ_MCP_TASK_Q',
            dequeue_options    => l_dequeue_options,
            message_properties => l_message_properties,
            payload            => l_message,
            msgid              => l_message_handle
        );
    exception
        when e_no_messages or e_no_message_id then
            rollback;
            return;
    end;

    begin
        select * into l_task
          from oj_mcp_task_states
         where task_id = l_message.task_id;
    exception
        when no_data_found then
            commit;
            return;
    end;

    if l_task.cancel_requested = 1 or l_task.status = 'cancelled' then
        commit;
        return;
    end if;

    apex_util.set_workspace(upper(l_task.ords_pattern));
    apex_session.create_session(
        p_app_id   => l_task.apex_app_id,
        p_page_id  => l_task.apex_page_id,
        p_username => l_task.owner_name
    );
    select sys_context('APEX$SESSION', 'APP_SESSION')
      into l_apex_session_id
      from dual;
    l_apex_created := true;

    if l_task.ras_config_pkg is not null then
        execute immediate
            'begin :1 := ' || dbms_assert.sql_object_name(l_task.ras_config_pkg)
            || '.PREPARE_NAMESPACE(:2); end;'
            using out l_nsattrlist, l_task.owner_name;
        oj_mcp_ras_ctx.create_session(
            l_task.owner_name,
            l_apex_session_id,
            l_nsattrlist
        );
        l_ras_created := true;
    end if;

    if l_task.arguments_json is not null then
        l_arguments := json_object_t.parse(l_task.arguments_json);
    end if;

    l_tool_result := oj_mcp_app_methods.generate_object_for_tools_call(
        p_name           => l_task.tool_name,
        p_args           => l_arguments,
        p_ras_config_pkg => l_task.ras_config_pkg,
        p_current_user   => l_task.owner_name,
        p_mcp_session_id => l_apex_session_id,
        p_execution_schema => l_task.execution_schema
    );

    cleanup_context;
    l_result_clob := l_tool_result.to_clob();

    update oj_mcp_task_states
       set status = 'completed',
           status_message = 'Tool execution completed.',
           result_json = l_result_clob,
           error_json = null,
           last_updated_at = systimestamp
     where task_id = l_task.task_id
       and cancel_requested = 0;
    commit;
exception
    when others then
        l_failure_message := substr(sqlerrm, 1, 3500);
        cleanup_context;

        if l_task.task_id is not null then
            l_error := json_object_t();
            l_error.put('code', C_INTERNAL_ERROR);
            l_error.put('message', 'Tool execution failed: ' || l_failure_message);
            l_error_clob := l_error.to_clob();
            update oj_mcp_task_states
               set status = 'failed',
                   status_message = 'Tool execution failed.',
                   error_json = l_error_clob,
                   result_json = null,
                   last_updated_at = systimestamp
             where task_id = l_task.task_id
               and cancel_requested = 0;
            commit;
            logger.log_error(l_failure_message, l_scope);
        else
            rollback;
            logger.log_error('Task worker failed before loading task: ' || l_failure_message, l_scope);
        end if;
end process_message;

end oj_mcp_tasks;
/
