create or replace package body oj_mcp_app_server
as

    gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

    C_MCP_PROTOCOL_VERSION_HEADER constant varchar2(20) := 'Mcp-Protocol-Version';
    C_PROTOCOL_VERSION constant varchar2(10) := '2026-07-28';
    C_UNSUPPORTED_PROTOCOL_VERSION constant number := -32022;
    C_HEADER_MISMATCH constant number := -32020;
    C_CACHE_TTL_MS constant number := 3600000;

    /* RAS support */
    g_ras_config_pkg varchar2(128)    := null;
    g_current_user   varchar2(128)    := null;
    g_mcp_session_id varchar2(128)    := null;

    procedure server_discover(
        p_context     in varchar2,
        p_capabilities in json_object_t,
        p_result      out clob,
        p_error       out clob,
        p_status_code out number
    )
    as
        l_result json_object_t := json_object_t();
        l_versions json_array_t := json_array_t();
        l_meta json_object_t := json_object_t();
        l_server_info json_object_t := json_object_t();
    begin
        l_versions.append(C_PROTOCOL_VERSION);
        l_result.put('supportedVersions', l_versions);
        l_result.put('capabilities', oj_mcp_app_methods.negotiate_client_server_capabilities(p_capabilities));
        l_server_info.put('name', p_context);
        l_server_info.put('version', '0.1.0');
        l_meta.put('io.modelcontextprotocol/serverInfo', l_server_info);
        l_result.put('_meta', l_meta);
        p_result := l_result.to_clob();
        p_error := null;
        p_status_code := 200;
    end server_discover;

    procedure add_result_envelope(
        p_result in out clob,
        p_context in varchar2,
        p_cacheable in boolean
    )
    as
        l_result json_object_t := json_object_t(p_result);
        l_meta json_object_t;
        l_server_info json_object_t := json_object_t();
    begin
        l_result.put('resultType', 'complete');
        l_meta := l_result.get_object('_meta');
        if l_meta is null then l_meta := json_object_t(); end if;
        l_server_info.put('name', p_context);
        l_server_info.put('version', '0.1.0');
        l_meta.put('io.modelcontextprotocol/serverInfo', l_server_info);
        l_result.put('_meta', l_meta);
        if p_cacheable then
            l_result.put('ttlMs', C_CACHE_TTL_MS);
            l_result.put('cacheScope', 'private');
        end if;
        p_result := l_result.to_clob();
    end add_result_envelope;

    function decode_mcp_header_value(
        p_value in varchar2
    ) return varchar2
    as
        l_encoded varchar2(32767);
        l_raw raw(32767);
    begin
        if substr(p_value, 1, 9) != '=?base64?' or substr(p_value, -2) != '?=' then
            return p_value;
        end if;

        l_encoded := substr(p_value, 10, length(p_value) - 11);
        if mod(length(l_encoded), 4) != 0
           or not regexp_like(l_encoded, '^[A-Za-z0-9+/]*={0,2}$') then
            return null;
        end if;

        l_raw := sys.utl_encode.base64_decode(sys.utl_raw.cast_to_raw(l_encoded));
        return sys.utl_i18n.raw_to_char(l_raw, 'AL32UTF8');
    exception
        when others then
            return null;
    end decode_mcp_header_value;

    function request_origin_is_allowed return boolean
    as
        l_origin varchar2(4000) := owa_util.get_cgi_env('Origin');
        l_count pls_integer;
    begin
        if l_origin is null then
            return true;
        end if;

        select count(*)
          into l_count
          from oj_mcp_allowed_origins
         where lower(origin) = lower(trim(l_origin));

        return l_count > 0;
    end request_origin_is_allowed;

    /*
     * MCP handler implementation.
     */

    procedure tools_list(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope logger_logs.scope%type := gc_scope_prefix || 'tools_list';

        l_tools_arr   json_array_t;
        l_result_json json_object_t;
        l_error_json  json_object_t;
    begin
        logger.log_info('p_context: ' || p_context, l_scope);
        l_tools_arr := oj_mcp_app_methods.generate_array_for_list_tools(p_context);
        l_result_json := json_object_t();
        l_result_json.put('tools', l_tools_arr);
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
        logger.log_info('result: ' || p_result, l_scope);
    exception
        when others then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INTERNAL_ERROR);
            l_error_json.put('message', 'Error in tools_list: ' || sqlerrm);
            logger.log_error(sqlerrm, l_scope);
            logger.log_error(dbms_utility.format_error_stack, l_scope);
            logger.log_error(dbms_utility.format_error_backtrace, l_scope);
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 500;
    end tools_list;

    procedure tools_call(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope logger_logs.scope%type := gc_scope_prefix || 'tools_call';

        l_params      json_object_t;
        l_name        varchar2(128);
        l_args_obj    json_object_t;
        l_result_json json_object_t;
        l_error_json  json_object_t;
    begin
        /*
         * name parameter is mandatory; therefore, p_params must not be NULL.
         */
        if p_params is null then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INVALID_PARAMS);
            l_error_json.put('message', 'Invalid parameters: p_params is null');
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 400;
            return;
        end if;
        /*
         * Parse the parameters to retrieve name and arguments.
         */
        l_params := json_object_t.parse(p_params);
        l_name := l_params.get_string('name');
        /*
         * Since name is mandatory, return an error if it is NULL.
         */
        if l_name is null then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INVALID_PARAMS);
            l_error_json.put('message', 'Invalid parameters: name is required');
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 400;
            return;
        end if;
        /*
         * The arguments parameter is optional.
         */
        l_args_obj := l_params.get_object('arguments');
        /*
         * Execute Tool.
         */
        l_result_json := oj_mcp_app_methods.generate_object_for_tools_call(
            p_name => l_name,
            p_args => l_args_obj,
            p_ras_config_pkg => g_ras_config_pkg,
            p_current_user => g_current_user,
            p_mcp_session_id => g_mcp_session_id
        );
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
    exception
        when others then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INTERNAL_ERROR);
            l_error_json.put('message', 'Error in tools_call: ' || sqlerrm);
            logger.log_error(sqlerrm, l_scope);
            logger.log_error(dbms_utility.format_error_stack, l_scope);
            logger.log_error(dbms_utility.format_error_backtrace, l_scope);
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 500;
    end tools_call;

    procedure resources_list(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope logger_logs.scope%type := gc_scope_prefix || 'resources_list';

        l_resources_arr json_array_t;
        l_result_json   json_object_t;
        l_error_json    json_object_t;
    begin
        logger.log_info('p_context: ' || p_context, l_scope);
        l_resources_arr := oj_mcp_app_methods.generate_array_for_list_ui_resources(p_context);
        l_result_json := json_object_t();
        l_result_json.put('resources', l_resources_arr);
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
        logger.log_info('result: ' || p_result, l_scope);
    exception
        when others then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INTERNAL_ERROR);
            l_error_json.put('message', 'Error in resources_list: ' || sqlerrm);
            logger.log_error(sqlerrm, l_scope);
            logger.log_error(dbms_utility.format_error_stack, l_scope);
            logger.log_error(dbms_utility.format_error_backtrace, l_scope);
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 500;
    end resources_list;

    procedure resources_read(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope logger_logs.scope%type := gc_scope_prefix || 'resources_read';

        l_params json_object_t;
        l_uri varchar2(1000);
        l_result_json  json_object_t;
        l_contents_arr json_array_t;
        l_error_json   json_object_t;
    begin
        logger.log_info('resources_read is called with parameters: ' || p_params, l_scope);
        /*
         * uri parameter is mandatory; therefore, p_params must not be NULL.
         */
        if p_params is null then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INVALID_PARAMS);
            l_error_json.put('message', 'Invalid parameters: p_params is null');
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 400;
            return;
        end if;
        /*
         * Parse the parameters to retrieve name and arguments.
         */
        l_params := json_object_t.parse(p_params);
        l_uri := l_params.get_string('uri');
        /*
         * Since uri is mandatory, return an error if it is NULL.
         */
        if l_uri is null then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INVALID_PARAMS);
            l_error_json.put('message', 'Invalid parameters: uri is required');
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 400;
            return;
        end if;
        /*
         * Build contents for resourceUri
         */
        l_contents_arr := oj_mcp_app_methods.generate_array_for_read_ui_resource(l_uri);

        if l_contents_arr.get_size() = 0 then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INVALID_PARAMS);
            l_error_json.put('message', 'Invalid parameters: resource URI is not found');
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 400;
            return;
        end if;

        /* Format output.  */
        l_result_json := json_object_t();
        l_result_json.put('contents', l_contents_arr);
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
        logger.log_info('Resource read successfully for uri ' || l_uri, l_scope);
    exception
        when others then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INTERNAL_ERROR);
            l_error_json.put('message', 'Error in resources_read: ' || sqlerrm);
            logger.log_error(sqlerrm, l_scope);
            logger.log_error(dbms_utility.format_error_stack, l_scope);
            logger.log_error(dbms_utility.format_error_backtrace, l_scope);
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 500;
    end resources_read;

    procedure resources_templates_list(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope logger_logs.scope%type := gc_scope_prefix || 'resources_templates_list';

        l_resource_templates_arr json_array_t := json_array_t();
        l_result_json json_object_t;
    begin
        l_result_json := json_object_t();
        l_result_json.put('resourceTemplates', l_resource_templates_arr);
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
    end resources_templates_list;

    /**
     * Procedure that is called within ORDS REST handler.
     */
    procedure ords_handler(
        p_script_name   in  varchar2
        ,p_username     in  varchar2
        ,p_request      in  blob
        ,p_response     out blob
        ,p_status_code  out number
        ,p_ras_config_pkg in varchar2 default null
    )
    as
        l_scope logger_logs.scope%type := gc_scope_prefix || 'ords_handler';

        C_SCRIPT_PATH_PATTERN   constant varchar2(30) := '/([^\/]+)/([^\/]+)/mcp$';

        /*
         * JSONRPC Request.
         */
        l_request_json json_object_t;
        l_id           sys.anydata;
        l_method       varchar2(128);
        l_params_obj   json_object_t;
        l_params       clob;
        l_version      varchar2(16);
        l_username     varchar2(128);
        l_protocol_header varchar2(32);
        l_protocol_version varchar2(32);
        l_method_header varchar2(128);
        l_name_header varchar2(1000);
        l_expected_name varchar2(1000);
        l_request_meta json_object_t;
        l_client_capabilities json_object_t;
        l_apex_session_id varchar2(128);
        l_error_data json_object_t;
        l_supported_versions json_array_t;
        /*
         * ORDS pattern (ORDS alias) could be different from APEX workspace name.
         * but this code is assumed that both are assigned the same name.
         *
         * The ORDS module name cloud be different from the URI prefix,
         * but this code is assumed that both are assigned the same name.
         */
        l_ords_pattern     user_ords_schemas.pattern%type;
        l_ords_module_name user_ords_modules.name%type;
        l_apex_app_id      apex_applications.application_id%type;
        l_apex_page_id     apex_application_pages.page_id%type;
        /*
         * MCP method invocation.
         */
        l_result      clob;
        l_error       clob;
        l_status_code number;
        l_response_json json_object_t;
        /*
         * RAS
         */
        l_nsattrlist sys.dbms_xs_nsattrlist;
    begin
        /*
         * Since the system is currently under development, set the default logging level of the Logger to INFO.
         */
        logger.set_level('INFORMATION');

        if not request_origin_is_allowed then
            p_status_code := 403;
            p_response := oj_mcp_jsonrpc_utils.create_error_response(
                p_id      => null,
                p_code    => C_INVALID_REQUEST,
                p_message => 'Origin is not allowed for this MCP endpoint.'
            );
            return;
        end if;

        /*
         * Extract the ORDS pattern and the module name from the script name.
         */
        select
            regexp_substr(p_script_name, C_SCRIPT_PATH_PATTERN, 1, 1, null, 1),
            regexp_substr(p_script_name, C_SCRIPT_PATH_PATTERN, 1, 1, null, 2)
        into l_ords_pattern, l_ords_module_name from dual;
        logger.log_info('ORDS Pattern found '     || l_ords_pattern,     l_scope);
        logger.log_info('ORDS Module Name found ' || l_ords_module_name, l_scope);

        /*
         * Assume ORDS alias as the APEX workspace name and set it as active workspace.
         */
        begin
            apex_util.set_workspace(upper(l_ords_pattern));
        exception
            when others then
                logger.log_error('Failed to set APEX workspace ' || l_ords_pattern || ' ' || sqlerrm, l_scope);
                logger.log_error(dbms_utility.format_error_stack, l_scope);
                logger.log_error(dbms_utility.format_error_backtrace, l_scope);
                raise;
        end;

        /*
         * Assume ORDS module name as APEX application alias then get app_id and page_id.
         */
        begin
            select application_id into l_apex_app_id from apex_applications
            where workspace = upper(l_ords_pattern) and alias = upper(l_ords_module_name);
        exception
            when no_data_found then
                logger.log_error('No APEX application with alias ' || l_ords_module_name || ' found. ' || sqlerrm, l_scope);
                logger.log_error(dbms_utility.format_error_stack, l_scope);
                logger.log_error(dbms_utility.format_error_backtrace, l_scope);
                raise;
        end;

        /*
         * Identify the page number contained in the application.
         */
        select min(page_id) into l_apex_page_id from apex_application_pages
        where application_id = l_apex_app_id and page_id > 0;

        /*
         * If an ORDS REST service is protected by a JWT profile, the sub claim in the Bearer token is 
         * passed to p_username. If p_username is NULL, the REST service is not protected.
         */
        if p_username is not null then
            /* 
             * Use the sub claim in the Bearer token as-is as the username.
             * In some cases (e.g., Microsoft Entra ID), the sub claim may be a value that is not practical
             *  to use directly as a username.
             */
            l_username := p_username;
            logger.log_info('Use sub claim in Bearer token as a username: ' || l_username, l_scope);
        else
            /*
             * Use the database user when no authentication is provided. 
             */
            select sys_context('USERENV', 'CURRENT_USER') into l_username from dual;
            logger.log_info('Use database user as a username: ' || l_username, l_scope);
        end if;

        /*
         * Validate and parse the JSON-RPC message, and extract the id, method, and params attributes.
         */
        begin
            l_request_json := json_object_t(p_request);

            /*
             * Verify that the JSON-RPC version is 2.0.
             */
            l_version := l_request_json.get_string('jsonrpc');
            if l_version is null or l_version != '2.0' then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id      => null,
                    p_code    => C_INVALID_REQUEST,
                    p_message => 'Invalid JSON-RPC version. Expected "2.0".'
                );
                logger.log_error('Invalid JSON-RPC version', l_scope);
                return;
            else
                logger.log_info('JSON-RPC version is ' || l_version, l_scope);
            end if;

            /*
             * Extract the method value. The method is mandatory.
             */
            l_method := l_request_json.get_string('method');
            if l_method is null then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id      => null,
                    p_code    => C_INVALID_REQUEST,
                    p_message => 'Method is required in the request.'
                );
                logger.log_error('Method is required in the request', l_scope);
                return;
            else
                logger.log_info('Request method is ' || l_method, l_scope);
            end if;

            /* Every method implemented by this endpoint is a JSON-RPC request. */
            l_id := oj_mcp_jsonrpc_utils.get_id(l_request_json);
            if l_id is null then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id      => null,
                    p_code    => C_INVALID_REQUEST,
                    p_message => 'id is required for supported MCP methods.'
                );
                return;
            end if;
            logger.log_info('jsonrpc request id is ' || oj_mcp_jsonrpc_utils.id_to_string(l_id), l_scope);

            /*
             * Whether params is mandatory depends on the method.
             */
            l_params_obj := l_request_json.get_object('params');
            if l_params_obj is not null then
                l_params := l_params_obj.to_clob();
                logger.log_info('params found in the request: ' || l_params, l_scope);
            else
                logger.log_info('No params in the request', l_scope);
            end if;

            /* MCP 2026-07-28 requires version and capabilities on every request. */
            l_protocol_header := owa_util.get_cgi_env(C_MCP_PROTOCOL_VERSION_HEADER);
            if l_protocol_header is null then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_HEADER_MISMATCH,
                    'MCP-Protocol-Version header is required.');
                return;
            elsif l_protocol_header != C_PROTOCOL_VERSION then
                l_supported_versions := json_array_t();
                l_supported_versions.append(C_PROTOCOL_VERSION);
                l_error_data := json_object_t();
                l_error_data.put('supported', l_supported_versions);
                l_error_data.put('requested', l_protocol_header);
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_UNSUPPORTED_PROTOCOL_VERSION,
                    'Unsupported MCP protocol version: ' || l_protocol_header,
                    l_error_data.to_clob());
                return;
            end if;

            if l_params_obj is null then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_INVALID_REQUEST,
                    'params with _meta are required for protocol ' || C_PROTOCOL_VERSION);
                return;
            end if;
            l_request_meta := l_params_obj.get_object('_meta');
            if l_request_meta is null then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_INVALID_REQUEST,
                    '_meta is required for protocol ' || C_PROTOCOL_VERSION);
                return;
            end if;
            l_protocol_version := l_request_meta.get_string('io.modelcontextprotocol/protocolVersion');
            l_client_capabilities := l_request_meta.get_object('io.modelcontextprotocol/clientCapabilities');
            if l_protocol_version is null or l_client_capabilities is null then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_INVALID_REQUEST,
                    'protocolVersion and clientCapabilities are required in _meta');
                return;
            end if;
            if l_protocol_version != l_protocol_header then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_HEADER_MISMATCH,
                    'MCP-Protocol-Version header does not match params._meta protocolVersion');
                return;
            end if;

            l_method_header := owa_util.get_cgi_env('Mcp-Method');
            if l_method_header is null or l_method_header != l_method then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_HEADER_MISMATCH,
                    'Mcp-Method header does not match the JSON-RPC method');
                return;
            end if;

            if l_method in ('tools/call', 'resources/read') then
                l_name_header := decode_mcp_header_value(owa_util.get_cgi_env('Mcp-Name'));
                if l_method = 'resources/read' then
                    l_expected_name := l_params_obj.get_string('uri');
                else
                    l_expected_name := l_params_obj.get_string('name');
                end if;
                if l_name_header is null or l_expected_name is null or l_name_header != l_expected_name then
                    p_status_code := 400;
                    p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_HEADER_MISMATCH,
                        'Mcp-Name header does not match the JSON-RPC request');
                    return;
                end if;
            end if;

            if l_method not in ('server/discover', 'tools/list', 'tools/call', 'resources/list',
                                'resources/read', 'resources/templates/list') then
                p_status_code := 404;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(l_id, C_METHOD_NOT_FOUND,
                    'Method ' || l_method || ' not found.');
                return;
            end if;

        exception
            when others then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id => null,
                    p_code => C_PARSE_ERROR,
                    p_message => 'Invalid JSON format in request body. sqlerrm: ' || sqlerrm
                );
                logger.log_error('Invalid JSON format in request body. sqlerrm: ' || sqlerrm, l_scope);
                logger.log_error(dbms_utility.format_error_stack, l_scope);
                logger.log_error(dbms_utility.format_error_backtrace, l_scope);
                return;
        end;
        
        /* APEX and RAS contexts are internal and live only for this request. */
        apex_session.create_session(
            p_app_id   => l_apex_app_id,
            p_page_id  => l_apex_page_id,
            p_username => l_username
        );
        select sys_context('APEX$SESSION','APP_SESSION') into l_apex_session_id from dual;
        g_ras_config_pkg := p_ras_config_pkg;
        g_current_user := l_username;
        g_mcp_session_id := l_apex_session_id;
        if p_ras_config_pkg is not null then
            execute immediate
                'begin :1 := ' || dbms_assert.sql_object_name(p_ras_config_pkg) || '.PREPARE_NAMESPACE(:2); end;'
                using out l_nsattrlist, p_username;
            oj_mcp_ras_ctx.create_session(l_username, l_apex_session_id, l_nsattrlist);
        end if;

        /*
         * Set MODULE and ACTION for database observability.
         */
        begin
            dbms_application_info.set_module(
                module_name => l_ords_module_name,
                action_name => l_apex_session_id || ':' || oj_mcp_jsonrpc_utils.id_to_string(l_id)
            );
        end;

        /*
         * Invoke the MCP method.
         */
        case l_method
            when 'server/discover' then
                server_discover(l_ords_module_name, l_client_capabilities, l_result, l_error, l_status_code);
            when 'tools/list' then 
                tools_list(l_username, l_params, l_ords_module_name, l_result, l_error, l_status_code);
            when 'tools/call' then 
                tools_call(l_username, l_params, l_ords_module_name, l_result, l_error, l_status_code);
            when 'resources/list' then 
                resources_list(l_username, l_params, l_ords_module_name, l_result, l_error, l_status_code);
            when 'resources/read' then 
                resources_read(l_username, l_params, l_ords_module_name, l_result, l_error, l_status_code);
            when 'resources/templates/list' then 
                resources_templates_list(l_username, l_params, l_ords_module_name, l_result, l_error, l_status_code);
            else
                p_status_code := 404;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id      => l_id,
                    p_code    => C_METHOD_NOT_FOUND,
                    p_message => 'Method ' || l_method || ' not found.'
                );
                logger.log_error('Method ' || l_method || ' not found.', l_scope);
                return;
        end case;

        /*
         * Return the response. 
        */
        p_status_code := l_status_code;
        if l_error is null and l_result is not null then
            add_result_envelope(
                l_result,
                l_ords_module_name,
                l_method in ('server/discover', 'tools/list', 'resources/list', 'resources/read', 'resources/templates/list')
            );
        end if;
        if l_id is not null then
            /*
             * If an id is present, it is a standard request.
             */
            if l_error is not null then
                /* Preserve the method-specific JSON-RPC error code and data. */
                l_response_json := json_object_t();
                l_response_json.put('jsonrpc', '2.0');
                l_response_json := oj_mcp_jsonrpc_utils.put_id(l_response_json, l_id);
                l_response_json.put('error', json_object_t(l_error));
                p_response := l_response_json.to_blob();
            else
                /*
                 * Return a response if the processing completes successfully.
                 */
                p_response := oj_mcp_jsonrpc_utils.create_success_response(
                    p_id      => l_id
                    ,p_result => l_result
                );
            end if;      
        end if;

        /*
         * Detach from APEX session.
        */
        apex_session.detach;
        begin
            if p_ras_config_pkg is not null then
                oj_mcp_ras_ctx.destroy_session(l_username, l_apex_session_id);
            end if;
            apex_session.delete_session(l_apex_session_id);
        exception when others then
            logger.log_error('Failed to delete request-scoped APEX session: ' || sqlerrm, l_scope);
        end;
    exception
        when others then
            /*
             * Return an error response if an exception occurs.
             */
            p_status_code := 500;
            p_response := oj_mcp_jsonrpc_utils.create_error_response(
                p_id      => l_id,
                p_code    => C_INTERNAL_ERROR,
                p_message => 'Internal Server Error: ' || sqlerrm
            );
            /* 
             * Detach the APEX session regardless of the context.
             */
            begin
                apex_session.detach;
            exception
                when others then
                    logger.log_error('Failed to detach APEX session: ' || g_mcp_session_id || ' ' || sqlerrm, l_scope);
                    logger.log_error(dbms_utility.format_error_stack, l_scope);
                    logger.log_error(dbms_utility.format_error_backtrace, l_scope);
            end;
            if l_apex_session_id is not null then
                begin
                    if p_ras_config_pkg is not null then
                        oj_mcp_ras_ctx.destroy_session(l_username, l_apex_session_id);
                    end if;
                    apex_session.delete_session(l_apex_session_id);
                exception when others then
                    logger.log_error('Failed to delete request-scoped APEX session: ' || sqlerrm, l_scope);
                end;
            end if;
    end ords_handler;

end oj_mcp_app_server;
/
