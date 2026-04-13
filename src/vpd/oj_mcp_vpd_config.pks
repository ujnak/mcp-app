create or replace package oj_mcp_vpd_config
as

procedure init(
    p_current_user in varchar2
);

end;
/