create or replace package body oj_mcp_app_utils
as

gc_scope_prefix constant varchar2(31 char) := lower($$plsql_unit) || '.';

/**
 * Update text in OJ_MCP_UI_RESOURCES by HTML bundle generated from APEX page definition.
 */
procedure update_app_text_from_apex_page(
    p_resource_name         in varchar2,
    p_resource_uri          in varchar2,
    p_page_url              in varchar2
)
as
    l_scope logger_logs.scope%type := gc_scope_prefix || 'update_app_text_from_apex_page';

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
        logger.log_error('Failed to get HTML bundle from APEX page. URL: ' || p_page_url 
            || ', HTTP status code: ' || apex_web_service.g_status_code, l_scope);
        raise e_failed_to_get_html_bundle;
    end if;
    /* 
     * APEX does not assign the type="module" attribute when embedding inline JavaScript;
     * this applies to the relevant target.
     */
    if regexp_instr(l_html_bundle_clob, '<script\s+type="module"\s') = 0 then
        l_html_bundle_clob := replace(l_html_bundle_clob, '<script ', '<script type="module" ');
    end if;
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

end oj_mcp_app_utils;
/