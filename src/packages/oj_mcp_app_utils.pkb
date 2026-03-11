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
               end into l_log_level_logger
            from dual;
            select
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
               end into l_log_level_apex
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
    function negoticate_client_server_capabilities(
        p_client_capabilities_json in json_object_t
    ) return json_object_t
    as
        l_scope uc_ai_logger.scope := gc_scope_prefix || 'negoticate_client_server_capabilities';
        l_server_capabilities_json json_object_t;
        l_resources_json           json_object_t;
        l_tools_json               json_object_t;
        l_client_extensions_json   json_object_t;
    begin
        uc_ai_logger.log_info('client capabilities: ' || p_client_capabilities_json.to_clob(), l_scope);

        /* construct negosiated capabilities */
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
    end negoticate_client_server_capabilities;

end oj_mcp_app_utils;
/