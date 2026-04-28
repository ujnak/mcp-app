whenever sqlerror continue

create or replace type oj_mcp_tools_message_t as object(
    body clob -- JSON
);
/
begin
    dbms_aqadm.create_queue_table(
        queue_table => 'oj_mcp_tools_q_tab'
        ,queue_payload_type => 'oj_mcp_tools_message_t'
        ,multiple_consumers => TRUE
    );
end;
/
begin
    dbms_aqadm.create_queue(
        queue_name => 'oj_mcp_tools_in_q'
        ,queue_table => 'oj_mcp_tools_q_tab'
    );
end;
/
begin
    dbms_aqadm.create_queue(
        queue_name => 'oj_mcp_tools_out_q'
        ,queue_table => 'oj_mcp_tools_q_tab'
    );
end;
/
begin
    dbms_aqadm.start_queue(
        queue_name => 'oj_mcp_tools_in_q'
    );
end;
/
begin
    dbms_aqadm.start_queue(
        queue_name => 'oj_mcp_tools_out_q'
    );
end;
/

declare
    subscriber         sys.aq$_agent;
begin
    subscriber     :=  sys.aq$_agent('APEXDEV', NULL, NULL);
    DBMS_AQADM.ADD_SUBSCRIBER(
        queue_name  =>  'apexdev.oj_mcp_tools_in_q',
        subscriber  =>  subscriber
    );
end;
/
declare
    subscriber         sys.aq$_agent;
begin
    subscriber     :=  sys.aq$_agent('APEXDEV', NULL, NULL);
    DBMS_AQADM.ADD_SUBSCRIBER(
        queue_name  =>  'apexdev.oj_mcp_tools_out_q',
        subscriber  =>  subscriber
    );
END;
/