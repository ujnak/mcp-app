create or replace package body oj_mcp_jsonrpc_utils
as

    gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

    /**
     * Create a JSONRPC messege from success result.
     */
    function create_success_response(
        p_id       in number
        ,p_result  in clob
    )
    return blob
    as
        l_response_json json_object_t;
    begin
        l_response_json := json_object_t();
        l_response_json.put('jsonrpc', '2.0');
        l_response_json.put('id', p_id);
        l_response_json.put('result', json_object_t(p_result));
        return l_response_json.to_blob;
    end create_success_response;

    /**
     * Create a JSONRPC message from error result.
     */
    function create_error_response(
        p_id       in number
        ,p_code    in number
        ,p_message in varchar2
        ,p_data    in clob default null
    )
    return blob
    as
        l_response_json json_object_t;
        l_error_json    json_object_t;
    begin
        l_response_json := json_object_t();
        l_response_json.put('jsonrpc', '2.0');
        l_response_json.put('id', p_id);
        l_error_json := json_object_t();
        l_error_json.put('code', p_code);
        l_error_json.put('message', p_message);
        if p_data is not null then
            l_error_json.put('data', json_object_t(p_data));
        end if;
        l_response_json.put('error', l_error_json);
        return l_response_json.to_blob;
    end create_error_response;

end oj_mcp_jsonrpc_utils;
/