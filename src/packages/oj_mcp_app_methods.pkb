create or replace package body oj_mcp_app_methods
as

gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

/*
 * The execution of dynamic PL/SQL code using DBMS_SQL is based 
 * on the UC_AI_TOOLS_API package provided by United Codes.
 * In addition, the value from the UC_AI_TOOLS.FUNCTION_CALL table is used
 * as the string for #FC_CODE#.
 */
C_PLSQL_BLOCK constant varchar2(32767) := q'[declare
    function user_function
    return clob
    as
    begin
        #FC_CODE#
    end user_function;
begin
    :return_val := user_function;
end;]';

/**
 * Set APEX and Logger log level from  MCP log level.
 */
procedure set_log_level(
    p_log_level in varchar2
)
as
    l_scope logger_logs.scope%type := gc_scope_prefix || 'set_log_level';
    l_log_level_logger varchar2(16) := null;
    l_log_level_apex   pls_integer  := null;
begin
    if p_log_level is not null then
        select
            case p_log_level
                when 'debug'     then 'DEBUG'
                when 'info'      then 'INFORMATION'
                when 'notice'    then 'WARNING'
                when 'warning'   then 'WARNING'
                when 'error'     then 'ERROR'
                when 'critical'  then 'PERMANENT'
                when 'alert'     then 'PERMANENT'
                when 'emergency' then 'PERMANENT'
                else null
            end log_level_logger,
            case p_log_level
                -- currently APEX trace for MCP debug is too much.
                -- when 'debug'     then apex_debug.c_log_level_trace
                when 'debug'     then apex_debug.c_log_level_info
                when 'info'      then apex_debug.c_log_level_info
                when 'notice'    then apex_debug.c_log_level_warn
                when 'warning'   then apex_debug.c_log_level_warn
                when 'error'     then apex_debug.c_log_level_error
                when 'critical'  then apex_debug.c_log_level_error
                when 'alert'     then apex_debug.c_log_level_error
                when 'emergency' then apex_debug.c_log_level_error
                else null
            end log_level_apex        
            into l_log_level_logger, l_log_level_apex
        from dual;
    end if;
    if l_log_level_logger is not null then
        logger.set_level(l_log_level_logger);
        logger.log_info('Logger log level is now ' || l_log_level_logger, l_scope);
    else
        logger.set_level('OFF');
        logger.log_info('Logger log is disabled', l_scope);
    end if;
    if l_log_level_apex   is not null then
        apex_debug.enable(l_log_level_apex);
        logger.log_info('APEX log level is now ' || l_log_level_apex, l_scope);
    else
        apex_debug.disable();
        logger.log_info('APEX log is disabled', l_scope);
    end if;
end set_log_level;

/**
 * Client Server capability negotiation.
 */
function negotiate_client_server_capabilities(
    p_client_capabilities_json in json_object_t
) return json_object_t
as
    l_scope logger_logs.scope%type := gc_scope_prefix || 'negotiate_client_server_capabilities';
    l_server_capabilities_json json_object_t;
    l_resources_json           json_object_t;
    l_tools_json               json_object_t;
    l_client_extensions_json   json_object_t;
begin
    logger.log_info('client capabilities: ' || p_client_capabilities_json.to_clob(), l_scope);

    /* construct negotiated capabilities */
    l_server_capabilities_json := json_object_t();

    /*
        * logging is always provided.
        * Ref: https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/logging#capabilities
        */
    l_server_capabilities_json.put('logging', json_object_t());

    /* 
        * resources for MCP App support
        * Ref: https://modelcontextprotocol.io/specification/2025-11-25/server/resources#capabilities
        */
    l_resources_json := json_object_t();
    l_resources_json.put('subscribe', false);
    l_resources_json.put('listChanged', true);
    l_server_capabilities_json.put('resources', l_resources_json);

    /*
        * tools support
        * Ref: https://modelcontextprotocol.io/specification/2025-11-25/server/tools#capabilities
        */
    l_tools_json := json_object_t();
    l_tools_json.put('listChanged', true);
    l_server_capabilities_json.put('tools', l_tools_json);

    /*
        * Clients that support the MCP App include the following entry in the capabilities.extensions field.
        * Ref: https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx#clientserver-capability-negotiation
        *
        * "extensions": {
        *     "io.modelcontextprotocol/ui": {
        *         "mimeTypes": ["text/html;profile=mcp-app"]
        *     }
        * }
        *
        * Only text/html;profile=mcp-app is supported as a UI mimeType. Therefore, validation of the mimeType is necessary;
        * however, it is omitted in the current implementation.
　　     */
    l_client_extensions_json := p_client_capabilities_json.get_object('extensions');
    if l_client_extensions_json is not null then
        if l_client_extensions_json.get_object('io.modelcontextprotocol/ui') is not null then
            l_server_capabilities_json.put('extensions',  l_client_extensions_json);
        end if;
    end if;

    logger.log_info('server capabilities: ' || l_server_capabilities_json.to_clob(), l_scope);
    return l_server_capabilities_json;
end negotiate_client_server_capabilities;

/**
 * Generate JSON array of tools for tools/list.
 */
function generate_array_for_list_tools(
    p_context in varchar2
)
return json_array_t
as
    l_scope logger_logs.scope%type := gc_scope_prefix || 'generate_array_for_list_tools';

    l_tool_json json_object_t;
    l_tools_arr json_array_t;
    /* MCP App resource _meta data */
    l_meta       json_object_t;
    l_meta_uri   json_object_t;
    l_visibility json_array_t;
begin
    logger.log_info('p_context: ' || p_context, l_scope);

    l_tools_arr := json_array_t();
    for r in (
        select
            t.code tool_name, t.description description, t.response_schema parameters
            ,t.output_schema output_schema, t.visibility, r.uri uri
        from oj_mcp_uc_ai_tools t 
            join uc_ai_tool_tags g on t.id = g.tool_id
            left outer join oj_mcp_ui_resources r on t.resource_id = r.id
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
        if r.uri is not null then
            l_meta     := json_object_t();
            l_meta_uri := json_object_t();
            l_meta_uri.put('resourceUri', r.uri);
            /* visibility, 1 = model, 2 = app, 3 = both */
            l_visibility := json_array_t();
            if bitand(r.visibility, 1) = 1 then l_visibility.append('model'); end if;
            if bitand(r.visibility, 2) = 2 then l_visibility.append('app'); end if;
            if l_visibility.get_size() > 0 then l_meta_uri.put('visibility', l_visibility); end if;
            l_meta.put('ui', l_meta_uri);
            l_tool_json.put('_meta', l_meta);
        end if;
        l_tools_arr.append(l_tool_json);
    end loop;
    logger.log_info('tools: ' || l_tools_arr.to_clob(), l_scope);
    return l_tools_arr;
end generate_array_for_list_tools;

/**
 * Generate JSON array of content for tools/call.
 */
function generate_object_for_tools_call(
    p_name           in varchar2,
    p_args           in json_object_t,
    p_ras_config_pkg in varchar2 default null,
    p_current_user   in varchar2 default null,
    p_mcp_session_id in varchar2 default null
)
return json_object_t
as
    l_scope logger_logs.scope%type := gc_scope_prefix || 'generate_object_for_tools_call';

    l_content_arr json_array_t;
    l_out         clob;
    l_args_clob   clob;
    l_out_obj     json_object_t;
    l_result_json json_object_t;
    l_output_schema oj_mcp_uc_ai_tools.output_schema%type;
    /* execute immediate */
    l_fc_code     uc_ai_tools.function_call%type := null;
    l_plsql_block varchar2(32767);
    l_found_binds apex_t_varchar2 := apex_t_varchar2();
    /* dbms_sql */
    l_cursor_id pls_integer;
    l_rows_fetched pls_integer;
    l_ras_session_id raw(16);
    is_error boolean := false;
    /* resource manager */
    l_resource_consumer_group_new varchar2(32) := null;
    l_resource_consumer_group_old varchar2(32) := null;
    /* RAS Dynamic Roles */
    l_dynamic_roles sys.xs$name_list := null;
begin
    /* retrieve function code from uc_ai_tools */
    begin
        select function_call, resource_consumer_group, output_schema
        into l_fc_code, l_resource_consumer_group_new, l_output_schema
        from oj_mcp_uc_ai_tools where code = p_name;
        logger.log_info('l_fc_code ' || l_fc_code || ' for ' || p_name, l_scope);
    exception
        when no_data_found then
            logger.log_error('No code registered. ' || p_name, l_scope);
            raise_application_error(-20001, 'No code registered.');
    end;
    /* find bind variable in the function call */
    l_found_binds := apex_string.grep(
        p_str           => l_fc_code
        , p_pattern       => ':([a-zA-Z0-9:\_]+)'
        , p_modifier      => 'i'
        , p_subexpression => '1'
    );
    if l_found_binds is null then
        logger.log_info('No bind variable found', l_scope);
    elsif l_found_binds.count > 1 then
        logger.log_error('Too many bind variable. ' || l_fc_code, l_scope);
        raise_application_error(-20002, 'Too many bind variable. ' || p_name);
    elsif l_found_binds.count = 1 then
        logger.log_info('l_found_binds ' || l_found_binds(1), l_scope);
    end if;
    /*
     * Construct PL/SQL block to execute.
     */
    l_plsql_block := C_PLSQL_BLOCK;
    l_plsql_block := replace(l_plsql_block, '#FC_CODE#', l_fc_code);
    /* The username must be enclosed in double quotes. */
    l_plsql_block := replace(l_plsql_block, '#SESSION_USER#', 
        sys.dbms_assert.enquote_name(sys_context('USERENV', 'SESSION_USER')));
    l_plsql_block := replace(l_plsql_block, '#CURRENT_USER#',
        sys.dbms_assert.enquote_name(sys_context('USERENV', 'CURRENT_USER')));
    /* Sub in a Bearer token is external input, it must be sanitized before use */
    l_plsql_block := replace(l_plsql_block, '#AUTHENTICATED_IDENTITY#',
        sys.dbms_assert.enquote_name(str => p_current_user, capitalize => false));
    l_plsql_block := replace(l_plsql_block, '#MCP_SESSION_ID#', p_mcp_session_id);
    logger.log_info('l_plsql_block: ' || l_plsql_block,  l_scope);
    /*
     * switch resource consumer group.
     */
    if l_resource_consumer_group_new is not null then
        $IF $$is_autonomous $THEN
            begin
                select resource_consumer_group into l_resource_consumer_group_old
                from v$session where sid = sys_context('USERENV','SID');
                cs_session.switch_service(l_resource_consumer_group_new);
            exception
                when others then
                    /* Do not apply it if the current resource consumer group cannot be determined from V$SESSION. */
                    logger.log_info('No Resource Consumer Group available. ' || sqlerrm, l_scope);
                    l_resource_consumer_group_new := null;
            end;
        $ELSE
            begin
                dbms_session.switch_current_consumer_group(
                    new_consumer_group => l_resource_consumer_group_new,
                    old_consumer_group => l_resource_consumer_group_old,
                    initial_group_on_error => false
                );
            exception
                when others then
                    logger.log_error('Failed to switch resource consumer group. ' ||
                        l_resource_consumer_group_new || ' ' || sqlerrm, l_scope);
                    l_resource_consumer_group_new := null;
            end;
        $END
        logger.log_info('Current resource consumer group set to ' || l_resource_consumer_group_new, l_scope);
    end if;
    /*
     * Execute Tool by DBMS_SQL.
     */
    l_cursor_id := sys.dbms_sql.open_cursor;
    if l_found_binds is not null then
        l_args_clob := null;
        if p_args is not null then
            l_args_clob := p_args.to_clob();
        end if;
        logger.log_info('argument ' || l_args_clob, l_scope);
    end if;
    if p_ras_config_pkg is not null then
        begin
            /*
             * Get dynamic Roles
             */
            execute immediate 'begin :1 := ' || p_ras_config_pkg || '.GET_DYNAMIC_ROLES; end;'
                using out l_dynamic_roles;
                                    /*
             * Real Applicaiton Security Support.
             */
            l_ras_session_id := null;
            begin
                select sessionid into l_ras_session_id from dba_xs_sessions where cookie = p_current_user || '-' || p_mcp_session_id;
            exception
                when no_data_found then
                    l_out := 'No RAS session found for MCP Session, The session must be re-established.';
                    is_error := true;
                    logger.log_error('No RAS session found for MCP Session ' || p_mcp_session_id, l_scope);
                when others then
                    l_out := sqlerrm;
                    is_error := true;
            end;
            if l_ras_session_id is not null then
                logger.log_info('RAS Session attaching...' || l_ras_session_id, l_scope);
                sys.dbms_xs_sessions.attach_session(
                    sessionid            => l_ras_session_id,
                    enable_dynamic_roles => l_dynamic_roles
                );
                logger.log_info('RAS Session attached. ' || l_ras_session_id, l_scope);
                sys.dbms_sql.parse(l_cursor_id, l_plsql_block, sys.dbms_sql.native);
                sys.dbms_sql.bind_variable(l_cursor_id, ':return_val', l_out);
                if l_found_binds is not null then
                    logger.log_info('bind ' || l_found_binds(1) || ' value ' || l_args_clob, l_scope);
                    sys.dbms_sql.bind_variable(l_cursor_id, ':' || l_found_binds(1),  l_args_clob);
                end if;
                l_rows_fetched := sys.dbms_sql.execute(l_cursor_id);
                logger.log_info('RAS Session detaching...', l_scope);
                sys.dbms_xs_sessions.detach_session;
                logger.log_info('RAS Session detached.', l_scope);
            end if;
        exception
            when others then
                l_out := sqlerrm;
                is_error := true;
                logger.log_error('Failed to tools call: ' || l_out, l_scope);
                /* force to detach xs session */
                begin
                    logger.log_info('Force to detach RAS Session.', l_scope);
                    sys.dbms_xs_sessions.detach_session;
                exception
                    when others then
                        logger.log_info(sqlerrm, l_scope);
                end;
                -- raise;
        end;
    else
        begin
            sys.dbms_sql.parse(l_cursor_id, l_plsql_block, sys.dbms_sql.native);
            sys.dbms_sql.bind_variable(l_cursor_id, ':return_val', l_out);
            if l_found_binds is not null then
                logger.log_info('bind ' || l_found_binds(1) || ' value ' || l_args_clob, l_scope);
                sys.dbms_sql.bind_variable(l_cursor_id, ':' || l_found_binds(1),  l_args_clob);
            end if;
            l_rows_fetched := sys.dbms_sql.execute(l_cursor_id);
        exception
            when others then
                l_out := sqlerrm;
                is_error := true;
        end;
    end if;
    if not is_error then
        sys.dbms_sql.variable_value(l_cursor_id, ':return_val', l_out);
        logger.log_info('return_val: ' || l_out, l_scope);
    end if;
    begin
        sys.dbms_sql.close_cursor(l_cursor_id);
    exception
        when others then
            logger.log_info('close cursor failed. ' || sqlerrm, l_scope);
    end;
    /* 
     * Resource Manager Support.
     */
    if l_resource_consumer_group_old is not null then
        begin
            $IF $$is_autonomous $THEN
                cs_session.switch_service(l_resource_consumer_group_old);
            $ELSE
                dbms_session.switch_current_consumer_group(
                    new_consumer_group => l_resource_consumer_group_old,
                    -- 
                    old_consumer_group => l_resource_consumer_group_new,
                    initial_group_on_error => false
                );
            $END
            logger.log_info('Revert resource consumer group back to ' || l_resource_consumer_group_old, l_scope);
        exception
            when others then
                logger.log_info('Failed to change resource consumer group. ' || sqlerrm, l_scope);
        end;
    end if;
    /* Format output.  */
    l_content_arr := json_array_t();
    l_out_obj     := json_object_t();
    l_out_obj.put('type', 'text');
    l_out_obj.put('text', l_out);
    /* put tool output to content array */
    l_content_arr.append(l_out_obj);
    l_result_json := json_object_t();
    l_result_json.put('content', l_content_arr);
    /* is output_schema  defined ? if yes, include structuredContent */
    if l_output_schema is not null then
        l_result_json.put('structuredContent', json_object_t(l_out));
    end if;
    l_result_json.put('isError', is_error);
    logger.log_info('result: ' || l_result_json.to_clob(), l_scope);
    return l_result_json;
end generate_object_for_tools_call;

/**
 * Generate the JSON array that will serve as the value of resources in the resources/list response.
 * 
 * Generated by Claude Sonnet 4.6, Reviewed by ynakakos
 */
function generate_array_for_list_ui_resources(
    p_context in varchar2
)
return json_array_t
is
    l_scope logger_logs.scope%type := gc_scope_prefix || 'generate_array_for_list_ui_resources';

    l_resources  json_array_t  := json_array_t();

    -- CSP domains
    l_connect_domains   json_array_t;
    l_resource_domains  json_array_t;
    l_frame_domains     json_array_t;
    l_base_uri_domains  json_array_t;

    -- JSON builders
    l_resource_item  json_object_t;
    l_meta           json_object_t;
    l_meta_ui        json_object_t;
    l_csp            json_object_t;
    l_permissions    json_object_t;

begin
    logger.log_info('p_context: ' || p_context, l_scope);
    -- -------------------------------------------------------
    -- Loop through all resources
    -- -------------------------------------------------------
    for r in (
        select id, uri, name, description, mime_type, prefers_border, domain
        from oj_mcp_ui_resources
        where id in (
            select t.resource_id from oj_mcp_uc_ai_tools t join uc_ai_tool_tags g on t.id = g.tool_id
            where t.resource_id is not null and g.tag_name = lower(p_context)
        )
        order by id
    ) loop
        /*
         * Build resource item
         */
        l_resource_item := json_object_t();
        l_resource_item.put('uri',  r.uri);
        l_resource_item.put('name', r.name);
        if r.description is not null then
            l_resource_item.put('description', r.description);
        end if;
        l_resource_item.put('mimeType', r.mime_type);
        /*
         * _meta.ui
         */
        l_meta          := json_object_t();
        l_meta_ui       := oj_mcp_app_utils.generate_meta_ui(
            p_resource_id    => r.id
            ,p_domain         => r.domain
            ,p_prefers_border => r.prefers_border
        );
        if l_meta_ui.get_keys().count > 0 then
            l_meta.put('ui', l_meta_ui);
            l_resource_item.put('_meta', l_meta);
        end if;
        l_resources.append(l_resource_item);
    end loop;

    /*
     * Return an array of resource item.
     */
    logger.log_info('resources: ' || l_resources.to_clob(), l_scope);
    return l_resources;

end generate_array_for_list_ui_resources;


/** 
 * Generate JSON array that will be the contents of resources in the resources/read response.
 *
 * Generated by Claude Sonnet 4.6, Reviewed by ynakakos
 */
function generate_array_for_read_ui_resource(
    p_uri in oj_mcp_ui_resources.uri%type
) return json_array_t
is
    l_scope logger_logs.scope%type := gc_scope_prefix || 'generate_array_for_read_ui_resource';

    l_resource_id    oj_mcp_ui_resources.id%type;
    l_uri            oj_mcp_ui_resources.uri%type;
    l_name           oj_mcp_ui_resources.name%type;
    l_description    oj_mcp_ui_resources.description%type;
    l_mime_type      oj_mcp_ui_resources.mime_type%type;
    l_text           oj_mcp_ui_resources.text%type;
    l_prefers_border oj_mcp_ui_resources.prefers_border%type;
    l_domain         oj_mcp_ui_resources.domain%type;

    -- JSON builders
    l_contents     json_array_t  := json_array_t();
    l_content_item json_object_t := json_object_t();
    l_meta         json_object_t := json_object_t();
    l_meta_ui      json_object_t;
begin
    logger.log_info('uri: ' || p_uri, l_scope);

    /*
     * Fetch main resource
     */
    begin
        select id, uri, name, description, mime_type, text, prefers_border, domain
            into l_resource_id, l_uri, l_name, l_description, l_mime_type, l_text,
                l_prefers_border, l_domain
            from oj_mcp_ui_resources
        where uri = p_uri;
    exception
        when no_data_found then
            return l_contents;
    end;

    /*
     * Build contents[0] item
     *   Content element of resources/read response
     */
    l_content_item.put('uri',      l_uri);
    l_content_item.put('mimeType', l_mime_type);

    -- Attach _meta only when ui key has values
    l_meta_ui       := oj_mcp_app_utils.generate_meta_ui(
        p_resource_id     => l_resource_id
        ,p_domain         => l_domain
        ,p_prefers_border => l_prefers_border
    );
    if l_meta_ui.get_keys().count > 0 then
        l_meta.put('ui', l_meta_ui);
        l_content_item.put('_meta', l_meta);
    end if;

    -- text field
    l_content_item.put('text', l_text);
    l_contents.append(l_content_item);

    -- text is too big to log.
    -- logger.log_info('contents: ' || l_contents.to_clob(), l_scope);
    return l_contents;
end generate_array_for_read_ui_resource;

end oj_mcp_app_methods;
/
