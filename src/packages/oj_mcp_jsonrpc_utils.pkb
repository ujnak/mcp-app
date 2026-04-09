create or replace package body oj_mcp_jsonrpc_utils
as

    gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

    /** 
     * Extract id as anydata from the JSONRPC message.
     */
    function get_id(
        l_json  in json_object_t
        ,l_name in varchar2 default 'id'
    )
    return sys.anydata
    as
        l_scope logger_logs.scope%type := gc_scope_prefix || 'get_id';

        l_elem       json_element_t;
        l_id_anydata sys.anydata := null;
        l_id_number  number;
        l_id_string  varchar2(128);
    begin
        l_elem := l_json.get(l_name);
        if l_elem is not null then
            if l_elem.is_number then
                l_id_number := l_json.get_number(l_name);
                l_id_anydata := sys.anydata.convertnumber(l_id_number);
            elsif l_elem.is_string then
                l_id_string := l_json.get_string(l_name);
                l_id_anydata := sys.anydata.convertvarchar2(l_id_string);
            else
                /*
                 * TODO:
                 * If the JSON-RPC id cannot be handled as either a numeric value or a string,
                 * this constitutes a fatal error; therefore, an exception should ideally be raised using raise_application_error.
                 * 
                 * At present, since no application-specific error code has been defined for raise_application_error,
                 * the implementation returns NULL instead.
                 */
                logger.log_error('id is not number or string ' || l_elem.to_string(), l_scope);
            end if;
        end if;
        return l_id_anydata;
    end get_id;

    /**
     * Put id to JSONRPC message.
     */
    function put_id(
        l_json in out json_object_t
        ,l_id  in sys.anydata
    )
    return json_object_t
    as
        l_scope logger_logs.scope%type := gc_scope_prefix || 'put_id';
    begin
        if l_id is null then
            /* do nothing if id does not supplied */
            return l_json;
        end if;
        if l_id.gettypename = 'SYS.NUMBER' then
            l_json.put('id', sys.anydata.accessnumber(l_id));
        elsif l_id.gettypename = 'SYS.VARCHAR2' then
            l_json.put('id', sys.anydata.accessvarchar2(l_id));
        else
            /* should raise execption. */
            logger.log_error('id is not number or string ', l_scope);
        end if;
        return l_json;
    end put_id;
 
    /**
     * Convert id - anydata to printable string - varchar2.
     */
    function id_to_string(
        l_id in sys.anydata
    )
    return varchar2
    as
    begin
        if l_id is null then
            /* do nothing if id does not supplied */
            return null;
        end if;
        if l_id.gettypename = 'SYS.NUMBER' then
            return to_char(sys.anydata.accessnumber(l_id));
        elsif l_id.gettypename = 'SYS.VARCHAR2' then
            return sys.anydata.accessvarchar2(l_id);
        end if;
        /* should raise execption. */
        return null;
    end id_to_string;

    /**
     * Create a JSONRPC message from success result.
     */
    function create_success_response(
        p_id       in sys.anydata
        ,p_result  in clob
    )
    return blob
    as
        l_response_json json_object_t;
    begin
        l_response_json := json_object_t();
        l_response_json.put('jsonrpc', '2.0');
        -- l_response_json.put('id', p_id);
        l_response_json := put_id(l_response_json, p_id);
        l_response_json.put('result', json_object_t(p_result));
        return l_response_json.to_blob;
    end create_success_response;

    /**
     * Create a JSONRPC message from error result.
     */
    function create_error_response(
        p_id       in sys.anydata
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
        -- l_response_json.put('id', p_id);
        l_response_json := put_id(l_response_json, p_id);
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