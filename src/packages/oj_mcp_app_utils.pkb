create or replace package body oj_mcp_app_utils
as

gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

/**
 * Set APEX and Logger log level from  MCP log level.
 */
procedure set_log_level(
    p_log_level in varchar2
)
as
    l_scope uc_ai_logger.scope := gc_scope_prefix || 'set_log_level';
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
        uc_ai_logger.log_info('Logger log level is now ' || l_log_level_logger, l_scope);
    else
        logger.set_level('OFF');
        uc_ai_logger.log_info('Logger log is disabled', l_scope);
    end if;
    if l_log_level_apex   is not null then
        apex_debug.enable(l_log_level_apex);
        uc_ai_logger.log_info('APEX log level is now ' || l_log_level_apex, l_scope);
    else
        apex_debug.disable();
        uc_ai_logger.log_info('APEX log is disabled', l_scope);
    end if;
end set_log_level;

/**
    * Client Server capability negotiation.
    */
function negotiate_client_server_capabilities(
    p_client_capabilities_json in json_object_t
) return json_object_t
as
    l_scope uc_ai_logger.scope := gc_scope_prefix || 'negotiate_client_server_capabilities';
    l_server_capabilities_json json_object_t;
    l_resources_json           json_object_t;
    l_tools_json               json_object_t;
    l_client_extensions_json   json_object_t;
begin
    uc_ai_logger.log_info('client capabilities: ' || p_client_capabilities_json.to_clob(), l_scope);

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
    l_resources_json.put('subscribe', true);
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

    uc_ai_logger.log_info('server capabilities: ' || l_server_capabilities_json.to_clob(), l_scope);
    return l_server_capabilities_json;
end negotiate_client_server_capabilities;

/**
 * Update text in OJ_MCP_UI_RESOURCES by HTML bundle generated from APEX page definition.
 */
procedure update_app_text_from_apex_page(
    p_resource_name         in varchar2,
    p_resource_uri          in varchar2,
    p_page_url              in varchar2
)
as
    l_scope uc_ai_logger.scope := gc_scope_prefix || 'update_app_text_from_apex_page';

    l_html_bundle_clob clob;
    e_failed_to_get_html_bundle exception;
    l_update_user varchar2(80);
    l_update_time timestamp;
begin
    l_update_user := sys_context('USERENV', 'CURRENT_USER');
    l_update_time := current_timestamp;

    l_html_bundle_clob := apex_web_service.make_rest_request(
        p_url => p_page_url,
        p_http_method => 'GET'
    );
    if apex_web_service.g_status_code != 200 then
        uc_ai_logger.log_error('Failed to get HTML bundle from APEX page. URL: ' || p_page_url 
            || ', HTTP status code: ' || apex_web_service.g_status_code, l_scope);
        raise e_failed_to_get_html_bundle;
    end if;
    l_html_bundle_clob := replace(l_html_bundle_clob, '<script ', '<script type="module" ');
    merge into oj_mcp_ui_resources t
    using (
        select
            p_resource_name as name,
            l_html_bundle_clob as text
        from dual
    ) s
    on (t.name = s.name)
    when matched then
        update set
            t.text = s.text,
            t.updated_by = l_update_user,
            t.updated_at = l_update_time
    when not matched then
        insert (name, uri, mime_type, text, created_by, created_at, updated_by, updated_at)
        values (s.name, p_resource_uri, 'text/html;profile=mcp-app', s.text, l_update_user, l_update_time, l_update_user, l_update_time)
    ;
end update_app_text_from_apex_page;

/**
 * Generate JSON array of tools for tools/list.
 */
function generate_array_for_list_tools(
    p_context in varchar2
)
return json_array_t
as
    l_scope uc_ai_logger.scope := gc_scope_prefix || 'generate_array_for_list_tools';

    l_tool_json json_object_t;
    l_tools_arr json_array_t;
    /* MCP App resource _meta data */
    l_meta       json_object_t;
    l_meta_uri   json_object_t;
    l_visibility json_array_t;
begin
    uc_ai_logger.log_info('p_context: ' || p_context, l_scope);

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
    uc_ai_logger.log_info('tools: ' || l_tools_arr.to_clob(), l_scope);
    return l_tools_arr;
end generate_array_for_list_tools;

/**
 * Generate JSON array of content for tools/call.
 */
function generate_object_for_tools_call(
    p_name in varchar2,
    p_args in json_object_t
)
return json_object_t
as
    l_scope uc_ai_logger.scope := gc_scope_prefix || 'generate_array_for_list_tools';

    l_content_arr json_array_t;
    l_out clob;
    l_out_obj     json_object_t;
    l_result_json json_object_t;
begin
    uc_ai_logger.log_info('name: ' || p_name || ' args: ' || p_args.to_clob(), l_scope);
    /*
     * Execute Tool.
     */
    l_out := uc_ai_tools_api.execute_tool(p_name, p_args);
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
    l_result_json.put('structuredContent', json_object_t(l_out));
    l_result_json.put('isError', false);
    uc_ai_logger.log_info('content: ' || l_content_arr.to_clob(), l_scope);
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
    l_scope uc_ai_logger.scope := gc_scope_prefix || 'generate_array_for_list_ui_resources';

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
    uc_ai_logger.log_info('p_context: ' || p_context, l_scope);
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

        l_resource_item := json_object_t();
        l_meta          := json_object_t();
        l_meta_ui       := json_object_t();
        l_csp           := json_object_t();
        l_permissions   := json_object_t();

        l_connect_domains  := json_array_t();
        l_resource_domains := json_array_t();
        l_frame_domains    := json_array_t();
        l_base_uri_domains := json_array_t();

        -- -----------------------------------------------------
        -- 1. Collect CSP domains
        -- -----------------------------------------------------
        for c in (
            select domain_type, domain
              from oj_mcp_ui_csp_domains
             where resource_id = r.id
             order by domain_type, id
        ) loop
            case c.domain_type
                when 'CONNECT'  then l_connect_domains.append(c.domain);
                when 'RESOURCE' then l_resource_domains.append(c.domain);
                when 'FRAME'    then l_frame_domains.append(c.domain);
                when 'BASE_URI' then l_base_uri_domains.append(c.domain);
                else null;
            end case;
        end loop;

        if l_connect_domains.get_size()  > 0 then l_csp.put('connectDomains',  l_connect_domains);  end if;
        if l_resource_domains.get_size() > 0 then l_csp.put('resourceDomains', l_resource_domains); end if;
        if l_frame_domains.get_size()    > 0 then l_csp.put('frameDomains',    l_frame_domains);    end if;
        if l_base_uri_domains.get_size() > 0 then l_csp.put('baseUriDomains',  l_base_uri_domains); end if;

        -- -----------------------------------------------------
        -- 2. Collect permissions
        -- -----------------------------------------------------
        for p in (
            select perm_camera, perm_microphone, perm_geolocation, perm_clipboard_write
              from oj_mcp_ui_permissions
             where resource_id = r.id
        ) loop
            if p.perm_camera          = 1 then l_permissions.put('camera',         json_object_t('{}')); end if;
            if p.perm_microphone      = 1 then l_permissions.put('microphone',     json_object_t('{}')); end if;
            if p.perm_geolocation     = 1 then l_permissions.put('geolocation',    json_object_t('{}')); end if;
            if p.perm_clipboard_write = 1 then l_permissions.put('clipboardWrite', json_object_t('{}')); end if;
        end loop;

        -- -----------------------------------------------------
        -- 3. Build _meta.ui object
        -- -----------------------------------------------------
        if l_csp.get_keys().count > 0 then
            l_meta_ui.put('csp', l_csp);
        end if;

        if l_permissions.get_keys().count > 0 then
            l_meta_ui.put('permissions', l_permissions);
        end if;

        if r.domain is not null then
            l_meta_ui.put('domain', r.domain);
        end if;

        if r.prefers_border is not null then
            l_meta_ui.put('prefersBorder', case r.prefers_border when 1 then true else false end);
        end if;

        -- -----------------------------------------------------
        -- 4. Build resource item
        -- -----------------------------------------------------
        l_resource_item.put('uri',  r.uri);
        l_resource_item.put('name', r.name);

        if r.description is not null then
            l_resource_item.put('description', r.description);
        end if;

        l_resource_item.put('mimeType', r.mime_type);

        if l_meta_ui.get_keys().count > 0 then
            l_meta.put('ui', l_meta_ui);
            l_resource_item.put('_meta', l_meta);
        end if;

        l_resources.append(l_resource_item);

    end loop;

    -- -------------------------------------------------------
    -- 5. Return an array of resource item.
    -- -------------------------------------------------------
    uc_ai_logger.log_info('resources: ' || l_resources.to_clob(), l_scope);
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
    l_scope uc_ai_logger.scope := gc_scope_prefix || 'generate_array_for_read_ui_resource';

    l_resource_id    oj_mcp_ui_resources.id%type;
    l_uri            oj_mcp_ui_resources.uri%type;
    l_name           oj_mcp_ui_resources.name%type;
    l_description    oj_mcp_ui_resources.description%type;
    l_mime_type      oj_mcp_ui_resources.mime_type%type;
    l_text           oj_mcp_ui_resources.text%type;
    l_prefers_border oj_mcp_ui_resources.prefers_border%type;
    l_domain         oj_mcp_ui_resources.domain%type;

    -- CSP domains
    l_connect_domains   json_array_t := json_array_t();
    l_resource_domains  json_array_t := json_array_t();
    l_frame_domains     json_array_t := json_array_t();
    l_base_uri_domains  json_array_t := json_array_t();

    -- permissions
    l_perm_camera          number(1);
    l_perm_microphone      number(1);
    l_perm_geolocation     number(1);
    l_perm_clipboard_write number(1);

    -- JSON builders
    l_contents     json_array_t  := json_array_t();
    l_content_item json_object_t := json_object_t();
    l_meta         json_object_t := json_object_t();
    l_meta_ui      json_object_t := json_object_t();
    l_csp          json_object_t := json_object_t();
    l_permissions  json_object_t := json_object_t();

begin
    uc_ai_logger.log_info('uri: ' || p_uri, l_scope);
    -- -------------------------------------------------------
    -- 1. Fetch main resource
    -- -------------------------------------------------------
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

    -- -------------------------------------------------------
    -- 2. Collect CSP domains
    -- -------------------------------------------------------
    for rec in (
        select domain_type, domain
          from oj_mcp_ui_csp_domains
         where resource_id = l_resource_id
         order by domain_type, id
    ) loop
        case rec.domain_type
            when 'CONNECT'  then l_connect_domains.append(rec.domain);
            when 'RESOURCE' then l_resource_domains.append(rec.domain);
            when 'FRAME'    then l_frame_domains.append(rec.domain);
            when 'BASE_URI' then l_base_uri_domains.append(rec.domain);
            else null;
        end case;
    end loop;

    -- -------------------------------------------------------
    -- 3. Fetch permissions
    -- -------------------------------------------------------
    begin
        select perm_camera, perm_microphone, perm_geolocation, perm_clipboard_write
          into l_perm_camera, l_perm_microphone, l_perm_geolocation, l_perm_clipboard_write
          from oj_mcp_ui_permissions
         where resource_id = l_resource_id;
    exception
        when no_data_found then
            l_perm_camera          := 0;
            l_perm_microphone      := 0;
            l_perm_geolocation     := 0;
            l_perm_clipboard_write := 0;
    end;

    -- -------------------------------------------------------
    -- 4. Build CSP object (only when values exist)
    -- -------------------------------------------------------
    if l_connect_domains.get_size()  > 0 then l_csp.put('connectDomains',  l_connect_domains);  end if;
    if l_resource_domains.get_size() > 0 then l_csp.put('resourceDomains', l_resource_domains); end if;
    if l_frame_domains.get_size()    > 0 then l_csp.put('frameDomains',    l_frame_domains);    end if;
    if l_base_uri_domains.get_size() > 0 then l_csp.put('baseUriDomains',  l_base_uri_domains); end if;

    -- -------------------------------------------------------
    -- 5. Build permissions object (only requested ones)
    -- -------------------------------------------------------
    if l_perm_camera          = 1 then l_permissions.put('camera',         json_object_t('{}')); end if;
    if l_perm_microphone      = 1 then l_permissions.put('microphone',     json_object_t('{}')); end if;
    if l_perm_geolocation     = 1 then l_permissions.put('geolocation',    json_object_t('{}')); end if;
    if l_perm_clipboard_write = 1 then l_permissions.put('clipboardWrite', json_object_t('{}')); end if;

    -- -------------------------------------------------------
    -- 6. Build _meta.ui object
    -- -------------------------------------------------------
    if l_csp.get_keys().count > 0 then
        l_meta_ui.put('csp', l_csp);
    end if;

    if l_permissions.get_keys().count > 0 then
        l_meta_ui.put('permissions', l_permissions);
    end if;

    if l_domain is not null then
        l_meta_ui.put('domain', l_domain);
    end if;

    if l_prefers_border is not null then
        l_meta_ui.put('prefersBorder', case l_prefers_border when 1 then true else false end);
    end if;

    -- -------------------------------------------------------
    -- 7. Build contents[0] item
    --    Content element of resources/read response
    -- -------------------------------------------------------
    l_content_item.put('uri',      l_uri);
    l_content_item.put('mimeType', l_mime_type);

    -- Attach _meta only when ui key has values
    if l_meta_ui.get_keys().count > 0 then
        l_meta.put('ui', l_meta_ui);
        l_content_item.put('_meta', l_meta);
    end if;

    -- text field
    l_content_item.put('text', l_text);

    l_contents.append(l_content_item);

    -- text is too big to log.
    -- uc_ai_logger.log_info('contents: ' || l_contents.to_clob(), l_scope);
    return l_contents;
end generate_array_for_read_ui_resource;

end oj_mcp_app_utils;
/