declare
    l_roles    owa.vc_arr;
    l_modules  owa.vc_arr;
    l_patterns owa.vc_arr;
begin
    ords.create_role(
        p_role_name => 'ORDSUsers'
    );
    -- l_modules(1) := 'sampleserver';
    l_roles(1)   := 'ORDSUsers';
    ords.define_privilege(
        p_privilege_name => 'oracle.example.mcp',
        p_label          => 'Priviledge for MCP',
        p_roles          => l_roles,
        p_modules        => l_modules,
        p_patterns       => l_patterns    -- no assignment
    );
end;
/
