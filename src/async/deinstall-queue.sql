whenever sqlerror continue

declare
    subscriber         sys.aq$_agent;
begin
    subscriber     :=  sys.aq$_agent('APEXDEV', NULL, NULL);
    DBMS_AQADM.remove_SUBSCRIBER(
        queue_name  =>  'apexdev.oj_mcp_tools_in_q',
        subscriber  =>  subscriber
    );
end;
/

declare
    subscriber         sys.aq$_agent;
begin
    subscriber     :=  sys.aq$_agent('APEXDEV', NULL, NULL);
    DBMS_AQADM.remove_SUBSCRIBER(
        queue_name  =>  'apexdev.oj_mcp_tools_out_q',
        subscriber  =>  subscriber);
end;
/

begin
    dbms_aqadm.stop_queue(
        queue_name => 'oj_mcp_tools_in_q'
    );
end;
/

begin
    dbms_aqadm.stop_queue(
        queue_name => 'oj_mcp_tools_out_q'
    );
end;
/

begin
    dbms_aqadm.drop_queue(
        queue_name => 'oj_mcp_tools_in_q'
    );
end;
/

begin
    dbms_aqadm.drop_queue(
        queue_name => 'oj_mcp_tools_out_q'
    );
end;
/

begin
    dbms_aqadm.drop_queue_table(
        queue_table => 'oj_mcp_tools_q_tab'
    );
end;
/