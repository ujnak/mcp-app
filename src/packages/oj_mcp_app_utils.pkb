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

end oj_mcp_app_utils;
/