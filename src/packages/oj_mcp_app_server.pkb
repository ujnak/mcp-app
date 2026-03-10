create or replace package body oj_mcp_app_server
as

    gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

    C_MCP_SESSION_ID_HEADER constant varchar2(16) := 'Mcp-Session-Id';

    procedure initialize(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'initialize';

        l_params            json_object_t;
        l_client_protocol_version  varchar2(32);
        l_client_capabilities_json json_object_t;
        l_client_extensions_json   json_object_t;
        l_capabilities_json json_object_t;
        l_resources_json    json_object_t;
        l_tools_json        json_object_t;
        l_roots_json        json_object_t;
        l_error_json        json_object_t;

        l_request_json json_object_t;
        l_result_json  json_object_t;
        l_response clob;
        l_response_json json_object_t;
        l_id varchar2(128);
        l_si json_object_t;
    begin
        /*
         * Capabilities are determined based on the parameters sent by the client.
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
        l_params := json_object_t.parse(p_params);

        /* 
         * The capabilities parameter is mandatory for the initialize method; 
         * return an error if it is not found.
         */
        l_client_capabilities_json := l_params.get_object('capabilities');
        if l_client_capabilities_json is null then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INVALID_PARAMS);
            l_error_json.put('message', 'Invalid parameters: no capabilies in initialize');
            p_error := l_error_json.to_clob();
            p_result := null;
            p_status_code := 400;
            return;
        end if;

        /*
         * choose "2025-11-25" as a protocol version
         * if no prtocolVersion is requested by the client.
         */
        l_client_protocol_version  := l_params.get_string('protocolVersion');
        if l_client_protocol_version is null then
            uc_ai_logger.log_info('protocolVersion sent by the client: ' || l_client_protocol_version, l_scope);
            l_client_protocol_version := '2025-11-25';
        end if; 

        /* construct negosiated capabilities */
        l_capabilities_json := json_object_t();

        /* logging is always provided. */
        l_capabilities_json.put('logging', json_object_t());

        /* resources for MCP App support */
        l_resources_json := json_object_t();
        l_resources_json.put('listChanged', false);
        l_capabilities_json.put('resources', l_resources_json);

        /* tools support */
        l_tools_json := json_object_t();
        l_tools_json.put('listChanged', false);
        l_capabilities_json.put('tools', l_tools_json);

        /*
         * This server supports MCP App; therefore, include "io.modelcontextprotocol/ui"
         * in the extensions regardless of client declaration.
　　      */
        l_client_extensions_json := l_client_capabilities_json.get_object('extensions');
        if l_client_extensions_json is not null then
            if l_client_extensions_json.get_object('io.modelcontextprotocol/ui') is not null then
                l_capabilities_json.put('extensions',  l_client_extensions_json);
                uc_ai_logger.log_info('MCP App extension declared by client' || l_client_extensions_json.to_clob(), l_scope);
            else
                l_client_extensions_json := json_object_t('{"io.modelcontextprotocol/ui":{"mimeTypes":["text/html;profile=mcp-app"]}}');
                l_capabilities_json.put('extensions',  l_client_extensions_json);
                uc_ai_logger.log_info('MCP App extension added by server.', l_scope);
            end if;
        end if;

        p_status_code := 200;
        p_error := null;

        /* construct response */
        l_result_json := json_object_t();
        l_result_json.put('protocolVersion', l_client_protocol_version);
        l_result_json.put('capabilities',    l_capabilities_json);
        l_result_json.put('serverInfo', json_object_t('{ "name": "' || p_context || '", "version": "0.1.0" }'));
        p_result := l_result_json.to_clob();
        uc_ai_logger.log_info('capabilities determined by the server ' || p_result, l_scope);
    end initialize;

    procedure notifications_initialized(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'notifications_initialized';
    begin
        /* status code 204 for notifications.  */
        p_status_code := 204;
        p_error := null;
        p_result := null;
    end notifications_initialized;

    procedure logging_setlevel(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'logging_setlevel';

        l_params json_object_t;
        l_level  varchar2(16);
    begin
        l_params := json_object_t.parse(p_params);
        l_level := l_params.get_string('level');
        oj_mcp_app_utils.set_log_level(l_level);
        p_status_code := 200;
        p_error := null;
        p_result := '{}';
    end logging_setlevel;

    procedure tools_list(
        p_username     in varchar2
        ,p_params      in clob
        ,p_context     in varchar2
        ,p_result      out clob
        ,p_error       out clob
        ,p_status_code out number
    )
    as
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'tools_list';

        l_tool_json json_object_t;
        l_tools_arr json_array_t;
        l_result_json json_object_t;
        /* MCP App resource _meta data */
        l_meta     json_object_t;
        l_meta_uri json_object_t;
    begin
        /*
         * Reuse the UC_AI tool definition.
         * view oj_mcp_uc_ai_tools additionally has output_schema and resource_id for MCP App support.
         */
        l_tools_arr := json_array_t();
        for r in (
            select
                t.code tool_name, t.description description, t.response_schema parameters
                ,t.output_schema output_schema, r.resource_uri resource_uri
            from oj_mcp_uc_ai_tools t 
                join uc_ai_tool_tags g on t.id = g.tool_id
                left outer join oj_mcp_app_resources r on t.resource_id = r.id
            where g.tag_name = lower(p_context)
        )
        loop
            l_tool_json := json_object_t();
            l_tool_json.put('name', r.tool_name);
            l_tool_json.put('description', r.description);
            if r.parameters is not null then
                l_tool_json.put('inputSchema', json_object_t(r.parameters));
            end if;
            if r.output_schema is not null then
                l_tool_json.put('outputSchema', json_object_t(r.output_schema));
            end if;
            /*
             * MCP tool which has a resourceUri.
             */
            if r.resource_uri is not null then
                l_meta     := json_object_t();
                l_meta_uri := json_object_t();
                l_meta_uri.put('resourceUri', r.resource_uri);
                l_meta.put('ui', l_meta_uri);
                l_meta.put('ui/resourceUri', r.resource_uri);
                l_tool_json.put('_meta', l_meta);
            end if;
            l_tools_arr.append(l_tool_json);
        end loop;
        l_result_json := json_object_t();
        l_result_json.put('tools', l_tools_arr);
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
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
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'tools_call';

        l_params json_object_t;
        l_name varchar2(128);
        l_args_obj json_object_t;
        l_out clob;
        l_meta     json_object_t;
        l_meta_uri json_object_t;
        l_result_json json_object_t;
        l_content_arr json_array_t;
        l_out_obj json_object_t;
        l_response_json json_object_t;
        l_error_json    json_object_t;
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
        l_out := uc_ai_tools_api.execute_tool(l_name, l_args_obj);
        /* Format outout.  */
        l_result_json := json_object_t();
        l_content_arr := json_array_t();
        l_out_obj     := json_object_t();
        l_out_obj.put('type', 'text');
        l_out_obj.put('text', l_out);
        /* put tool output to content array */
        l_content_arr.append(l_out_obj);
        l_result_json.put('content', l_content_arr);
        /* add _meta if tool has a resourceUri for MCP App support */
        for r in (
            select r.resource_uri
            from oj_mcp_uc_ai_tools t join oj_mcp_app_resources r on t.resource_id = r.id
            where t.code = l_name
        )
        loop
            /* only a maximum of one row is selected. */
            l_meta     := json_object_t();
            l_meta_uri := json_object_t();
            l_meta_uri.put('resourceUri', r.resource_uri);
            l_meta.put('ui', l_meta_uri);
            l_meta.put('ui/resourceUri', r.resource_uri);
            l_result_json.put('_meta', l_meta);
        end loop;
        l_result_json.put('isError', false);
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
    exception
        when others then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INTERNAL_ERROR);
            l_error_json.put('message', 'Error in tools_call: ' || sqlerrm);
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
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'resources_list';

        l_resource_json json_object_t;
        l_resources_arr json_array_t;
        l_input_schema_json json_object_t;
        l_result_json json_object_t;
    begin
        l_resources_arr := json_array_t();
        for r in (
            select resource_name, resource_uri, mime_type
            from oj_mcp_uc_ai_tools t
                join oj_mcp_app_resources r on t.resource_id = r.id
                join uc_ai_tool_tags g on t.id = g.tool_id
            where g.tag_name = lower(p_context)
        )
        loop
            l_resource_json := json_object_t();
            l_resource_json.put('name',     r.resource_name);
            l_resource_json.put('uri',      r.resource_uri);
            l_resource_json.put('mimeType', r.mime_type);
            l_resources_arr.append(l_resource_json);
        end loop;
        l_result_json := json_object_t();
        l_result_json.put('resources', l_resources_arr);
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
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
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'resources_read';

        l_params json_object_t;
        l_uri varchar2(128);
        l_out clob;
        l_result_json  json_object_t;
        l_contents_arr json_array_t;
        l_resource     json_object_t;
        l_out_obj json_object_t;
        l_response_json json_object_t;
        l_error_json    json_object_t;
    begin
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
         * Read resource.
         */
        l_contents_arr := json_array_t();
        for r in (
            select resource_uri, mime_type, text from oj_mcp_app_resources
            where resource_uri = l_uri
        )
        loop
            l_resource := json_object_t();
            l_resource.put('uri',      r.resource_uri);
            l_resource.put('mimeType', r.mime_type);
            l_resource.put('text',     r.text); 
            l_contents_arr.append(l_resource);
        end loop;
        /* Format outout.  */
        l_result_json := json_object_t();
        l_result_json.put('contents', l_contents_arr);
        p_result := l_result_json.to_clob();
        p_error := null;
        p_status_code := 200;
    exception
        when others then
            l_error_json := json_object_t();
            l_error_json.put('code', C_INTERNAL_ERROR);
            l_error_json.put('message', 'Error in resources_read: ' || sqlerrm);
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
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'resources_templates_list';

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
        ,p_session_id   out varchar2
        ,p_status_code  out number
    )
    as
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'ords_handler';

        C_SCRIPT_PATH_PATTERN   constant varchar2(30) := '/([^\/]+)/([^\/]+)/mcp$';

        /*
         * JSONRPC Request.
         */
        l_request_json json_object_t;
        l_id           number;
        l_method       varchar2(128);
        l_params_obj   json_object_t;
        l_params       clob;
        l_version      varchar2(16);
        l_username     varchar2(128);
        /*
         * MCP Session = APEX Session.
         *
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
        l_session_id       varchar2(128);
        /*
         * MCP method invocation.
         */
        l_result      clob;
        l_error       clob;
        l_status_code number;
    begin
        /*
         * Since the system is currently under development, set the default logging level of the Logger to INFO.
         */
        logger.set_level('INFORMATION');

        /*
         * Extract the ORDS pattern and the module name from the script name.
         */
        select
            regexp_substr(p_script_name, C_SCRIPT_PATH_PATTERN, 1, 1, null, 1),
            regexp_substr(p_script_name, C_SCRIPT_PATH_PATTERN, 1, 1, null, 2)
        into l_ords_pattern, l_ords_module_name from dual;
        uc_ai_logger.log_info('ORDS Pattern found '     || l_ords_pattern,     l_scope);
        uc_ai_logger.log_info('ORDS Module Name found ' || l_ords_module_name, l_scope);

        /*
         * Assume ORDS alias as the APEX workspace name and set it as active workspace.
         */
        begin
            apex_util.set_workspace(upper(l_ords_pattern));
        exception
            when others then
                uc_ai_logger.log_error('Failed to set APEX workspace ' || l_ords_pattern || ' ' || sqlerrm, l_scope);
                raise;
        end;

        /*
         * Assume ORDS moule name as APEX application alias then get app_id and page_id.
         */
        begin
            select application_id into l_apex_app_id from apex_applications
            where workspace = upper(l_ords_pattern) and alias = upper(l_ords_module_name);
        exception
            when no_data_found then
                uc_ai_logger.log_error('No APEX application with alias ' || l_ords_module_name || ' found. ' || sqlerrm, l_scope);
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
            uc_ai_logger.log_info('Use sub claim in Bearer token as a username: ' || l_username, l_scope);
        else
            /*
             * Use the database user when no authentication is provided. 
             */
            select sys_context('USERENV', 'CURRENT_USER') into l_username from dual;
            uc_ai_logger.log_info('Use database user as a username: ' || l_username, l_scope);
        end if;

        /*
         * Retrieve the session ID passed via the Mcp-Session-Id header. This numeric value corresponds to 
         * the APEX session ID. However, it is preferable not to use the raw numeric value as-is; 
         * instead, protect the session ID (similarly to how APEX session cookies are handled) 
         * before assigning it to an HTTP header.
         */
        p_session_id := owa_util.get_cgi_env(C_MCP_SESSION_ID_HEADER);
        if p_session_id is null then
            uc_ai_logger.log_info(C_MCP_SESSION_ID_HEADER || ' not found', l_scope);
        else
            uc_ai_logger.log_info(C_MCP_SESSION_ID_HEADER || ' found, ID = ' || p_session_id, l_scope);
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
                uc_ai_logger.log_error('Invalid JSON-RPC version', l_scope);
                return;
            else
                uc_ai_logger.log_info('JSON-RPC version is ' || l_version, l_scope);
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
                uc_ai_logger.log_error('Method is required in the request', l_scope);
                return;
            else
                uc_ai_logger.log_info('Request method is ' || l_method, l_scope);
            end if;

            /*
             * Retrieve the request ID. In MCP Inspector, it is a numeric value.
             * For notifications, the value is NULL; therefore, no validation is required.
             */
            l_id := l_request_json.get_number('id');
            if l_id is null then
                uc_ai_logger.log_info('No id in the request', l_scope);
            else
                uc_ai_logger.log_info('jsonrpc request id is ' || l_id, l_scope);
            end if;

            /*
             * Whether params is mandatory depends on the method.
             */
            l_params_obj := l_request_json.get_object('params');
            if l_params_obj is not null then
                l_params := l_params_obj.to_clob();
                uc_ai_logger.log_info('params found in the request: ' || l_params, l_scope);
            else
                uc_ai_logger.log_info('No params in the request', l_scope);
            end if;

        exception
            when others then
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id => null,
                    p_code => C_PARSE_ERROR,
                    p_message => 'Invalid JSON format in request body. sqlerrm: ' || sqlerrm
                );
                uc_ai_logger.log_error('Invalid JSON format in request body. sqlerrm: ' || sqlerrm, l_scope);
                return;
        end;
        
        /*
         * Create a session when method is initialize.
         */
        if l_method = 'initialize' then
            apex_session.create_session(
                p_app_id    => l_apex_app_id
                ,p_page_id  => l_apex_page_id
                ,p_username => l_username
            );
            select sys_context('APEX$SESSION','APP_SESSION') into p_session_id from dual;
            if p_session_id is not null then
                uc_ai_logger.log_info('APEX session is created as ' || p_session_id, l_scope);
            else
                uc_ai_logger.log_error('APEX session can not be created.', l_scope);
            end if;
        else
            /* Attach the session if the session ID exists. */
            if p_session_id is not null then
                apex_session.attach(
                    p_app_id      => l_apex_app_id
                    ,p_page_id    => l_apex_page_id
                    ,p_session_id => p_session_id
                );
                uc_ai_logger.log_info('MCP session is attachted to APEX session ' || p_session_id, l_scope);
            else
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id      => l_id,
                    p_code    => C_INVALID_REQUEST,
                    p_message => 'Mcp-Session-Id is required for method: ' || l_method
                );
                uc_ai_logger.log_error('Mcp-Session-Id is required for method: ' || l_method, l_scope);
                return;
            end if;
        end if;

        /*
         * Invoke the MCP method.
         */
        case l_method
            when 'initialize' then
                initialize(l_username, l_params, l_ords_module_name, l_result, l_error, l_status_code);
            when 'notifications/initialized' then
                notifications_initialized(l_username, l_params, l_ords_module_name, l_result, l_error, l_status_code);
            when 'logging/setLevel' then
                logging_setlevel(l_username, l_params, l_ords_module_name, l_result, l_error, l_status_code);
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
                p_status_code := 400;
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id      => l_id,
                    p_code    => C_METHOD_NOT_FOUND,
                    p_message => 'Method ' || l_method || ' not found.'
                );
                uc_ai_logger.log_error('Method ' || l_method || ' not found.', l_scope);
                return;
        end case;

        /*
         * Return the response. 
         */
        p_status_code := l_status_code;
        if l_id is not null then
            /*
             * If an id is present, it is a standard request.
             */
            if l_error is not null then
                /*
                 * Return an error response if an error occurs.
                 */
                p_response := oj_mcp_jsonrpc_utils.create_error_response(
                    p_id      => l_id,
                    p_code    => C_INTERNAL_ERROR,
                    p_message => 'Error in MCP Server: ' || l_error
                );
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
    end ords_handler;

end oj_mcp_app_server;
/