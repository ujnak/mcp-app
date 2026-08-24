create or replace procedure oj_mcp_task_worker(
    context  raw,
    reginfo  sys.aq$_reg_info,
    descr    sys.aq$_descriptor,
    payload  varchar2,
    payloadl number
)
authid definer
as
begin
    oj_mcp_tasks.process_message(
        p_msgid         => case when descr is not null then descr.msg_id end,
        p_consumer_name => case when descr is not null then descr.consumer_name end
    );
end oj_mcp_task_worker;
/
