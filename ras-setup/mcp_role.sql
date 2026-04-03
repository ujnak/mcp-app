ADMIN
```
create role mcp_role;
grant select on wksp_apexdev.auth_users to mcp_role;
grant execute on wksp_apexdev.oj_mcp_ras_config to mcp_role;
grant select on wksp_apexdev.uc_ai_tools to mcp_role;
grant execute on wksp_apexdev.run_sql to mcp_role;
grant execute on wksp_apexdev.get_current_user to mcp_role;
grant execute on wksp_apexdev.get_schema to mcp_role;
grant mcp_role to rasadmin with admin option;
```

RASADMIN
```
begin
    sys.xs_principal.create_dynamic_role(
        name => 'MCPRUNTIME',
        scope => XS_PRINCIPAL.SESSION_SCOPE
    );
end;
/
grant mcp_role to mcpruntime;
```

include MCPRUNTIME to the dynanic roles.
