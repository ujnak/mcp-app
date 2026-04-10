create or replace package oj_mcp_vpd_config
as

procedure init(
    p_employee_id   in number,
    p_department_id in number
);

end;
/