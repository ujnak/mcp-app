create or replace package oj_mcp_app_utils
as
/**
 * Set APEX and Logger log level from  MCP log level.
 *
 * MCP Inspector sets following log levels.
 * debug, info, notice, warning, error, critical, alert, emergency
 *
 * APEX debug accepts following log levels.
 * error(1), warn(2), info(4), trace(6)
 *
 * OraOpenSource Logger accepts following log levels.
 * OFF(0), PERMANENT(1), ERROR(2), WARNING(4), INFORMATION(8),
 * DEBUG(16) and TIMING
 *
 * MCP Inspector | APEX     | Logger
 * debug         | trace(6) | DEBUG(16)
 * info          | info(4)  | INFORMATION(8)
 * notice        | warn(2)  | WARNING(4)
 * warning       | warn(2)  | WARNING(4)
 * error         | error(1) | ERROR(2)
 * critical      | error(1) | PERMANENT(1)
 * alert         | error(1) | PERMANENT(1)
 * emergency     | error(1) | PERMANENT(1)
 */
procedure set_log_level(
    p_log_level in varchar2
);

end oj_mcp_app_utils;
/