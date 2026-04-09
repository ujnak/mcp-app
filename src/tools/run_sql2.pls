create or replace function run_sql2(
    p_args in clob
)
return clob
authid current_user
/**
 * Execute an arbitrary SELECT statement and return result as a JSON array.
 */
as
    l_scope logger_logs.scope%type := 'run_sql2';

    C_STMT   constant varchar2(32767) :=
        'select * from (select * from (select a.*, row_number() over (order by null) apx$rownum from (%s) a) where apx$rownum <=:p$_max_rows) where apx$rownum>=:p$_first_row';
    C_OFFSET constant number := 0;
    C_LIMIT  constant number := 15;
    l_stmt   clob;
    l_args json_object_t;
    l_sql  varchar2(32767);
    l_offset number;
    l_limit  number;
    /*
     *
     */
    l_cursor         integer;
    l_col_cnt        integer;
    l_desc_tab       dbms_sql.desc_tab;
    l_rows_processed integer;
    /*
     *
     */
    l_val_varchar2   varchar2(4000);
    l_val_number     number;
    l_val_date       date;

    /* JSON output building */
    l_json_arr       json_array_t  := json_array_t();
    l_json_obj       json_object_t;
    l_row_count      number := 0;

    /* Column name cache (skipping apx$rownum) */
    type t_col_names is table of varchar2(128) index by pls_integer;
    l_col_names      t_col_names;

begin
    /*
     * retrieve sql, limit and offset from the argument json.
     */
    l_args := json_object_t(p_args);
    l_sql := trim(l_args.get_string('sql'));
    /* remove trailing ; from the sql */
    l_sql := rtrim(l_sql, ';');
    l_limit := l_args.get_number('limit');
    if l_limit is null then
        l_limit := C_LIMIT;
    end if;
    l_offset := l_args.get_number('offset');
    if l_offset is null then
        l_offset := C_OFFSET;
    end if;
    /*
     * wrap the select statement to enable pagination.
     */
    l_stmt := apex_string.format(C_STMT, l_sql);
    /*
     * Execute the SELECT statement provided by the caller.
     */
    l_cursor := dbms_sql.open_cursor;
    dbms_sql.parse(l_cursor, l_stmt, dbms_sql.native);
    -- bind offset and limit
    dbms_sql.bind_variable(l_cursor, ':p$_max_rows',  l_limit + l_offset);
    dbms_sql.bind_variable(l_cursor, ':p$_first_row', l_offset + 1);
    l_rows_processed := dbms_sql.execute(l_cursor);
    dbms_sql.describe_columns(l_cursor, l_col_cnt, l_desc_tab);

    -- cache column names and define columns for fetch
    for i in 1..l_col_cnt
    loop
        -- skip internal pagination column
        if lower(l_desc_tab(i).col_name) != 'apx$rownum' then
            l_col_names(i) := lower(l_desc_tab(i).col_name);
        end if;
        /*
         * TODO:
         * All data types other than NUMBER and DATE are currently being converted to VARCHAR2.
         * This section needs to implement format conversions tailored to each specific data type.
         */
        if l_desc_tab(i).col_type = 2 then
            dbms_sql.define_column(l_cursor, i, l_val_number);
        elsif l_desc_tab(i).col_type = 12 then
            dbms_sql.define_column(l_cursor, i, l_val_date);
        else
            dbms_sql.define_column(l_cursor, i, l_val_varchar2, 4000);
        end if;
    end loop;

    -- fetch rows and build JSON array
    while dbms_sql.fetch_rows(l_cursor) > 0
    loop
        l_row_count := l_row_count + 1;
        l_json_obj  := json_object_t();

        for i in 1..l_col_cnt
        loop
            -- skip the internal pagination column
            if not l_col_names.exists(i) then
                continue;
            end if;

            if l_desc_tab(i).col_type = 2 then
                dbms_sql.column_value(l_cursor, i, l_val_number);
                if l_val_number is not null then
                    l_json_obj.put(l_col_names(i), l_val_number);
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            elsif l_desc_tab(i).col_type = 12 then
                dbms_sql.column_value(l_cursor, i, l_val_date);
                if l_val_date is not null then
                    l_json_obj.put(l_col_names(i), to_char(l_val_date, 'YYYY-MM-DD'));
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            else
                dbms_sql.column_value(l_cursor, i, l_val_varchar2);
                if l_val_varchar2 is not null then
                    l_json_obj.put(l_col_names(i), l_val_varchar2);
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            end if;
        end loop;

        l_json_arr.append(l_json_obj);
    end loop;

    dbms_sql.close_cursor(l_cursor);

    logger.log_info('json row_count=' || l_row_count, l_scope);

    return l_json_arr.to_clob();

exception
    when others then
        if dbms_sql.is_open(l_cursor) then
            dbms_sql.close_cursor(l_cursor);
        end if;
        logger.log_error('run_sql2 failed: ' || sqlerrm, l_scope);
        -- return error details as JSON
        declare
            l_err json_object_t := json_object_t();
            l_err_detail json_object_t := json_object_t();
        begin
            l_err_detail.put('code', sqlcode);
            l_err_detail.put('message', sqlerrm);
            l_err_detail.put('backtrace', dbms_utility.format_error_backtrace());
            l_err.put('error', l_err_detail);
            return l_err.to_clob();
        end;
end run_sql2;
/