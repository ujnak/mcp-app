create or replace package test_run_sql as

    --%suite(execute select function as mcp tool)

    --%test(Returns single row of X)
    procedure select_dual;
    
end;
/

create or replace package body test_run_sql as

procedure select_dual
is
    l_args clob;
    l_args_obj json_object_t;
    l_result clob;
    l_json_array json_array_t;
    l_json_object json_object_t;
    l_dummy_value varchar2(4000 char);
begin
    l_args_obj := json_object_t();
    l_args_obj.put('sql', 'select * from dual');
    l_args := l_args_obj.to_clob();
    l_result := run_sql(l_args);

    -- Verify that the return value is a JSON array
    begin
        l_json_array := json_array_t.parse(l_result);
        ut.expect(1).to_equal(1); -- Parse succeeded = value is a JSON array
    exception
        when others then
            ut.fail('Return value is not a JSON array: ' || sqlerrm);
        return;
    end;

    -- Verify that the array contains exactly one element
    ut.expect(l_json_array.get_size()).to_equal(1);

    -- Verify that the array element is a JSON object
    begin
        l_json_object := treat(l_json_array.get(0) as json_object_t);
        ut.expect(l_json_object is not null).to_be_true();
    exception
        when others then
            ut.fail('Array element is not a JSON object: ' || sqlerrm);
        return;
    end;

    -- Verify that the JSON object has a DUMMY attribute with value X
    l_dummy_value := l_json_object.get_string('DUMMY');
    ut.expect(l_dummy_value).to_equal('X');
end select_dual;

end test_run_sql;
/

begin
    ut.run('test_run_sql');
end;
/