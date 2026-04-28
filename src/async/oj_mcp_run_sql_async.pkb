create or replace package body oj_mcp_run_sql_async
as

gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

function submit(
    p_args in clob
)
return clob
as
    pragma autonomous_transaction;
    l_scope logger_logs.scope%type := 'submit';

    enqueue_options     dbms_aq.enqueue_options_t;
    message_properties  dbms_aq.message_properties_t;
    message_handle      raw(16);
    message             apexdev.oj_mcp_tools_message_t;
    l_id number;
begin
    /*
     * Commit when enqueuing the message.
     * Because an autonomous transaction is configured, the commit may be redundant.
     */
    enqueue_options.visibility := sys.dbms_aq.immediate;
    enqueue_options.sequence_deviation := sys.dbms_aq.top;
    /*
     * Pass the received parameters through without modification.
     */
    message := apexdev.oj_mcp_tools_message_t(
        body => p_args
    );
    /*
     * assign id to the message which will be enqueued.
     */
    l_id := to_number(rawtohex(sys.dbms_crypto.randombytes(8)), 'XXXXXXXXXXXXXXXX');
    message_properties.correlation := l_id;
    /*
     * Enqueue the request.
     */
    dbms_aq.enqueue(
        queue_name           => 'apexdev.oj_mcp_tools_in_q'
        ,enqueue_options     => enqueue_options
        ,message_properties  => message_properties
        ,payload             => message
        ,msgid               => message_handle
    );
    return apex_string.format('[{ "job_id": "%s" }]', l_id);
end submit;

function get(
    p_args in clob
)
return clob
as
    pragma autonomous_transaction;
    l_scope logger_logs.scope%type := 'get';

    l_id       number;
    l_args_obj json_object_t;
    l_response clob;
    l_status   varchar2(16 char);
    C_RESPONSE_TEMPLATE constant varchar2(80 char) := '[{ "job_id":"%s", "job_status":"%s" }]';
begin
    l_args_obj := json_object_t.parse(p_args);
    l_id := l_args_obj.get_number('job_id');
    for r in (
        select msg_state from aq$oj_mcp_tools_q_tab where corr_id = l_id and queue = 'OJ_MCP_TOOLS_IN_Q'
    )
    loop
        if r.msg_state in ('READY','WAITING') then
            l_status := 'WAITING';
            l_response := apex_string.format(C_RESPONSE_TEMPLATE, l_id, l_status);
            return l_response;
        end if;
    end loop;
    for r in (
        select msg_state from aq$oj_mcp_tools_q_tab where corr_id = l_id and queue = 'OJ_MCP_TOOLS_OUT_Q'
    )
    loop
        if r.msg_state in ('READY','PROCESSED') then
            l_status := 'COMPLETED';
            return apex_string.format(C_RESPONSE_TEMPLATE, l_id, l_status);
        end if;
    end loop;
    l_status := 'PROCESSING';
    return apex_string.format(C_RESPONSE_TEMPLATE, l_id, l_status);
end get;

function result(
    p_args in clob
)
return clob
as
    pragma autonomous_transaction;

    l_scope logger_logs.scope%type := 'result';

    dequeue_options     dbms_aq.dequeue_options_t;
    message_properties  dbms_aq.message_properties_t;
    message_handle      raw(16);
    message             apexdev.oj_mcp_tools_message_t;
    l_id number;
    l_args_obj json_object_t;
    l_response clob;
begin
    /*
     * retrieve message id to be retrieved.
     */
    l_args_obj := json_object_t.parse(p_args);
    l_id := l_args_obj.get_number('job_id');
    dequeue_options.navigation := sys.dbms_aq.FIRST_MESSAGE;
    dequeue_options.consumer_name := 'APEXDEV';
    dequeue_options.correlation := l_id;
    dequeue_options.wait := sys.dbms_aq.NO_WAIT;
    -- dequeue_options.wait := 1;
    dequeue_options.dequeue_mode := sys.dbms_aq.REMOVE;
    dbms_aq.dequeue(
        queue_name          =>     'apexdev.oj_mcp_tools_out_q',
        dequeue_options     =>     dequeue_options,
        message_properties  =>     message_properties,
        payload             =>     message,
        msgid               =>     message_handle
    );
    l_response := message.body;
    commit;
    return l_response;
end result;

end oj_mcp_run_sql_async;