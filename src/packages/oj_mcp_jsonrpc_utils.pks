create or replace package oj_mcp_jsonrpc_utils
as
    /**
     * Extract the JSON-RPC id from the message as anydata,
     * since it may be either a numeric or string value.
     *
     * Although the attribute name is id, it becomes requestId in notification/cancelled messages;
     * therefore, l_name is added as a parameter.
     */
    function get_id(
        l_json  in json_object_t
        ,l_name in varchar2 default 'id'
    )
    return sys.anydata;

    /**
     * Put anydata as id to the message.
     */
    function put_id(
        l_json in out json_object_t
        ,l_id  in sys.anydata
    )
    return json_object_t;

    /**
     * Convert id - anydata to printable string - varchar2.
     */
    function id_to_string(
        l_id in sys.anydata
    )
    return varchar2;

     /**
     * Create a JSONRPC messege from success result.
     */
    function create_success_response(
        p_id       in sys.anydata
        ,p_result  in clob
    )
    return blob;

    /**
     * Create a JSONRPC message from error result.
     */
    function create_error_response(
        p_id       in sys.anydata
        ,p_code    in number
        ,p_message in varchar2
        ,p_data    in clob default null
    )
    return blob;

end oj_mcp_jsonrpc_utils;
/