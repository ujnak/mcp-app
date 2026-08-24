create or replace package oj_mcp_tasks
authid definer
as

C_EXTENSION_ID constant varchar2(64) := 'io.modelcontextprotocol/tasks';
C_MISSING_REQUIRED_CLIENT_CAPABILITY constant number := -32003;

function client_supports_tasks(
    p_client_capabilities in json_object_t
) return boolean;

function tool_tasks_enabled(
    p_tool_name in varchar2
) return boolean;

function create_tool_task(
    p_tool_name        in varchar2,
    p_arguments        in json_object_t,
    p_current_user     in varchar2,
    p_ords_pattern     in varchar2,
    p_ords_module_name in varchar2,
    p_apex_app_id      in number,
    p_apex_page_id     in number,
    p_ras_config_pkg   in varchar2 default null
) return json_object_t;

procedure get_task(
    p_params       in clob,
    p_current_user in varchar2,
    p_result       out clob,
    p_error        out clob,
    p_status_code  out number
);

procedure update_task(
    p_params       in clob,
    p_current_user in varchar2,
    p_result       out clob,
    p_error        out clob,
    p_status_code  out number
);

procedure cancel_task(
    p_params       in clob,
    p_current_user in varchar2,
    p_result       out clob,
    p_error        out clob,
    p_status_code  out number
);

procedure process_message(
    p_msgid         in raw,
    p_consumer_name in varchar2
);

end oj_mcp_tasks;
/
