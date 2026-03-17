create or replace procedure oj_mcp_ras_post_handler
(
    p_body         in blob,
    p_current_user in varchar2,
    p_status_code  out number
)
as
    /* 開発中 */
    l_response    blob;
    l_session_id  varchar2(128);
    l_status_code number;
    l_request     blob;
begin
    l_request := p_body;
    oj_mcp_app_server.ords_handler(
        p_script_name  => owa_util.get_cgi_env('SCRIPT_NAME') || owa_util.get_cgi_env('PATH_INFO') 
        ,p_username    => p_current_user
        ,p_request     => l_request
        ,p_response    => l_response
        ,p_session_id  => l_session_id
        ,p_status_code => l_status_code
    );
    /*
     * Return the response to the caller.
     */
    p_status_code := l_status_code;
    sys.htp.init;
    sys.htp.p('Content-Type: application/json');
    if l_session_id is not null then
        sys.htp.p('Mcp-Session-Id: ' || l_session_id);
    end if;
    if l_response is not null and dbms_lob.getlength(l_response) > 0 then
        sys.htp.p('Content-Length: ' || dbms_lob.getlength(l_response));
        sys.owa_util.http_header_close;
        sys.wpg_docload.download_file(l_response);
    else
        sys.owa_util.http_header_close;
    end if;
    commit;
end oj_mcp_ras_post_handler;
/