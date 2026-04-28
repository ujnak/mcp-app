create or replace package test_oj_mcp_run_sql_async as

    --%suite(execute select statement async as mcp tool)

    --%test(Submit single row of X)
    procedure submit_select_dual;

    --%test(Get job status)
    procedure get_select_dual;

    --%test(Returns single row of X)
    procedure result_select_dual;
end;
/

create or replace package body test_oj_mcp_run_sql_async as

g_job_id number;

procedure submit_select_dual
is
    l_args clob;
    l_args_obj json_object_t;
    l_result clob;
    l_json_array  json_array_t;
    l_json_object json_object_t;
begin
    l_args_obj := json_object_t();
    l_args_obj.put('sql', 'select * from dual');
    l_args := l_args_obj.to_clob();
    l_result := oj_mcp_run_sql_async.submit(l_args);
    dbms_output.put_line(l_result);
    /*
     * expected result:
     * [{ "job_id": "8102144616482314676" }]
     */
    l_json_array  := json_array_t.parse(l_result);
    l_json_object := treat(l_json_array.get(0) as json_object_t);
    g_job_id := l_json_object.get_number('job_id');
    ut.expect(1).to_equal(1);
exception
    when others then
        ut.fail('sql statement is failed to submit: ' || sqlerrm);
    return;
end submit_select_dual;

procedure get_select_dual
is
    l_args clob;
    l_args_obj json_object_t;
    l_result clob;
    l_json_array json_array_t;
    l_json_object json_object_t;
    l_job_status varchar2(4000 char);
begin
    l_args_obj := json_object_t();
    l_args_obj.put('job_id', g_job_id);
    l_args := l_args_obj.to_clob();
    l_result := oj_mcp_run_sql_async.get(l_args);
    dbms_output.put_line(l_result);
    /*
     * expected result: 
     * [{ "job_id": "8102144616482314676", "job_status": "PROCESSING" }]
     */
    l_json_array  := json_array_t.parse(l_result);
    l_json_object := treat(l_json_array.get(0) as json_object_t);
    l_job_status := l_json_object.get_string('job_status');
    ut.expect(l_job_status).not_to_be_null();
exception
    when others then
        ut.fail('response is not valid json object: ' || sqlerrm);
    return;
end get_select_dual;

procedure result_select_dual
is
    l_args clob;
    l_args_obj json_object_t;
    l_result clob;
    l_json_array json_array_t;
    l_json_object json_object_t;
    l_dummy_value varchar2(4000 char);
begin
    l_args_obj := json_object_t();
    l_args_obj.put('job_id', g_job_id);
    l_args := l_args_obj.to_clob();
    l_result := oj_mcp_run_sql_async.result(l_args);
    dbms_output.put_line(l_result);
    /*
     * expected result:
     * [{ "DUMMY": "X"}]
     */
    l_json_array  := json_array_t.parse(l_result);
    l_json_object := treat(l_json_array.get(0) as json_object_t);
    l_dummy_value := l_json_object.get_string('DUMMY');
    ut.expect(l_dummy_value).to_equal('X');
exception
    when others then
        ut.fail('sql result is not expected: ' || sqlerrm);
    return;
end result_select_dual;

end test_oj_mcp_run_sql_async;
/

begin
    ut.run('test_oj_mcp_run_sql_async.submit_select_dual');
    ut.run('test_oj_mcp_run_sql_async.get_select_dual');
    dbms_session.sleep(2);
    ut.run('test_oj_mcp_run_sql_async.result_select_dual');
    ut.run('test_oj_mcp_run_sql_async.get_select_dual');
end;
/