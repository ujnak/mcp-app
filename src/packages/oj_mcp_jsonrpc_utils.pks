create or replace package oj_mcp_jsonrpc_utils
as

     /**
     * Create a JSONRPC messege from success result.
     */
    function create_success_response(
        p_id       in number
        ,p_result  in clob
    )
    return blob;

    /**
     * Create a JSONRPC message from error result.
     */
    function create_error_response(
        p_id       in number
        ,p_code    in number
        ,p_message in varchar2
        ,p_data    in clob default null
    )
    return blob;

end oj_mcp_jsonrpc_utils;
/