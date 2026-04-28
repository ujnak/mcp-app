create or replace procedure tools_call_async(
    context raw, 
    reginfo sys.aq$_reg_info, 
    descr sys.aq$_descriptor,
    payload raw, payloadl number
)
as
    pragma autonomous_transaction;
    l_scope logger_logs.scope%type := 'tools_call_async';

    dequeue_options     sys.dbms_aq.dequeue_options_t;
    message_properties  sys.dbms_aq.message_properties_t;
    message_handle      raw(16);
    message             apexdev.oj_mcp_tools_message_t;
    l_request  clob;
    l_response clob;
    l_id number;
    --
    enqueue_options     dbms_aq.enqueue_options_t;
begin
    if descr is not null then
        -- If the argument descr has a value, the procedure is invoked as a notification.
        dequeue_options.msgid := descr.msg_id;
        dequeue_options.consumer_name := descr.consumer_name;
    end if;
    dequeue_options.navigation := sys.dbms_aq.FIRST_MESSAGE;
    /*
     * When invoked as a notification, no wait should occur.
     * When invoked by a scheduler job rather than as a notification,
     * the effective execution interval becomes: wait time + job repeat interval.
     */
    dequeue_options.wait := 60;
    sys.dbms_aq.dequeue(
        queue_name          =>     'apexdev.oj_mcp_tools_in_q',
        dequeue_options     =>     dequeue_options,
        message_properties  =>     message_properties,
        payload             =>     message,
        msgid               =>     message_handle
    );
    /*
     * arguments is retrieved from in queue.
     */
    l_request := message.body;
    /*
     * call run_sql asyncronously.
     * Currently, only run_sql is supported; however, the design should be extensible to
     *  accommodate additional tools in the future.
     */
    l_response := run_sql(l_request);
    /*
     * response message is sent to the out queue.
     */
    l_id := message_properties.correlation;
    message_properties.correlation := l_id;
    -- Enqueue a message indicating that processing has completed.
    enqueue_options.sequence_deviation := dbms_aq.top;
    -- メッセージは設定するが、通知としての使用のみで内容は参照しない。
    message := apexdev.oj_mcp_tools_message_t(l_response);
    dbms_aq.enqueue(
        queue_name          => 'apexdev.oj_mcp_tools_out_q'
        ,enqueue_options     => enqueue_options
        ,message_properties  => message_properties
        ,payload             => message
        ,msgid               => message_handle
    );
    commit;
end tools_call_async;
/