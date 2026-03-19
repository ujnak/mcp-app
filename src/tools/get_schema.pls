create or replace function get_schema(
    p_args in clob
)
return clob
/**
 * Return the specified schema information as a JSON document.
 */
as
    l_owner_object json_object_t;
    l_owner varchar2(128);
    l_schema clob;
begin
    l_owner_object := json_object_t(p_args);
    l_owner := l_owner_object.get_string('schema');
    if l_owner is null then
        /* set default owner */
        l_owner := SYS_CONTEXT('USERENV', 'CURRENT_USER');
    else
        l_owner := upper(l_owner);
    end if;
    select json_arrayagg(objects returning clob) into l_schema from (
        select json_object(table_name, columns) objects from (
            select table_name, json_arrayagg(json_object(column_name, data_type)) columns 
            from all_tab_columns where owner = l_owner group by table_name
        )
    );
    return l_schema;
end get_schema;
/
