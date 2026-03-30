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

/**
 * Generate _meta.ui object for the resource.
 */
function generate_meta_ui(
    p_resource_id    in oj_mcp_ui_resources.id%type,
    p_domain         in oj_mcp_ui_resources.domain%type,
    p_prefers_border in oj_mcp_ui_resources.prefers_border%type
)
return json_object_t
as
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
    l_meta_ui      json_object_t := json_object_t();
    l_csp          json_object_t := json_object_t();
    l_permissions  json_object_t := json_object_t();
begin
    -- -----------------------------------------------------
    -- 1. Collect CSP domains
    -- -----------------------------------------------------
    for c in (
        select domain_type, domain
        from oj_mcp_ui_csp_domains
        where resource_id = p_resource_id
        order by domain_type, id
    )
    loop
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
        where resource_id = p_resource_id
    )
    loop
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

    if p_domain is not null then
        l_meta_ui.put('domain', p_domain);
    end if;

    if p_prefers_border is not null then
        l_meta_ui.put('prefersBorder', case p_prefers_border when 1 then true else false end);
    end if;

    return l_meta_ui;
end generate_meta_ui;

end oj_mcp_app_utils;
/