create or replace function run_sql(
    p_args in clob
)
return clob
authid current_user
/**
 * Execute an arbitrary SELECT statement and return result as a JSON array.
 */
as
    l_scope logger_logs.scope%type := 'run_sql2';

    /*
     * The wrapper SQL for pagination is based on the APEX implementation.
     */
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
     * Dynamic SQL exection.
     */
    l_cursor         integer;
    l_col_cnt        integer;
    l_desc_tab       dbms_sql.desc_tab;
    l_rows_processed integer;
    /*
     * data conversion based on the data type.
     */
    l_val_varchar2      varchar2(32767);
    l_val_number        number;
    l_val_date          date;
    l_val_timestamp     timestamp;
    l_val_timestamp_tz  timestamp with time zone;
    l_val_timestamp_ltz timestamp with local time zone;
    l_val_clob          clob;
    
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
            l_col_names(i) := upper(l_desc_tab(i).col_name);
        end if;
        /*
         * TODO:
         * All data types other than NUMBER and DATE are currently being converted to VARCHAR2.
         * This section needs to implement format conversions tailored to each specific data type.
         *
         * https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Data-Types.html
         */
        if l_desc_tab(i).col_type = 1 then
            /* assume MAX_STRING_SIZE = STANDARD */
            dbms_sql.define_column(l_cursor, i, l_val_varchar2, 4000);
            /* MAX_STRING_SIZE = EXTENDED */
            -- dbms_sql.define_column(l_cursor, i, l_val_varchar2, 32767);
        elsif l_desc_tab(i).col_type = 2 then
            dbms_sql.define_column(l_cursor, i, l_val_number);
        elsif l_desc_tab(i).col_type = 12 then
            dbms_sql.define_column(l_cursor, i, l_val_date);
        elsif l_desc_tab(i).col_type = 180 then
            dbms_sql.define_column(l_cursor, i, l_val_timestamp);
        elsif l_desc_tab(i).col_type = 181 then
            dbms_sql.define_column(l_cursor, i, l_val_timestamp_tz);
        elsif l_desc_tab(i).col_type = 231 then
            dbms_sql.define_column(l_cursor, i, l_val_timestamp_ltz);
        elsif l_desc_tab(i).col_type = 112 then
            dbms_sql.define_column(l_cursor, i, l_val_clob);
        else
            /* ignore if data type is not varchar2, date variants or clob */
            logger.log_info('skip define_column for ' || l_col_names(i) || ' data_type = ' || l_desc_tab(i).col_type, l_scope);
            null;
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
            /*
             * get column value depend on the type and convert them into string.
             */
            if l_desc_tab(i).coL_type = 1 then
                dbms_sql.column_value(l_cursor, i, l_val_varchar2);
                if l_val_varchar2 is not null then
                    l_json_obj.put(l_col_names(i), l_val_varchar2);
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            elsif l_desc_tab(i).col_type = 2 then
                dbms_sql.column_value(l_cursor, i, l_val_number);
                if l_val_number is not null then
                    l_json_obj.put(l_col_names(i), l_val_number);
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            elsif l_desc_tab(i).col_type = 12 then
                dbms_sql.column_value(l_cursor, i, l_val_date);
                if l_val_date is not null then
                    l_json_obj.put(l_col_names(i), to_char(l_val_date, 'YYYY-MM-DD"T"HH24:MI:SS'));
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            elsif l_desc_tab(i).col_type = 180 then
                dbms_sql.column_value(l_cursor, i, l_val_timestamp);
                if l_val_timestamp is not null then
                    l_json_obj.put(l_col_names(i), to_char(l_val_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS'));
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            elsif l_desc_tab(i).col_type = 181 then
                dbms_sql.column_value(l_cursor, i, l_val_timestamp_tz);
                if l_val_timestamp_tz is not null then
                    l_json_obj.put(l_col_names(i), to_char((l_val_timestamp_tz at time zone 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS.FF"Z"'));
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            elsif l_desc_tab(i).col_type = 231 then
                dbms_sql.column_value(l_cursor, i, l_val_timestamp_ltz);
                if l_val_timestamp_ltz is not null then
                    l_json_obj.put(l_col_names(i), to_char((l_val_timestamp_ltz at time zone 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS.FF"Z"'));
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            elsif l_desc_tab(i).col_type = 112 then
                dbms_sql.column_value(l_cursor, i, l_val_clob);
                if l_val_clob is not null then
                    l_json_obj.put(l_col_names(i), l_val_clob);
                else
                    l_json_obj.put_null(l_col_names(i));
                end if;
            else
                logger.log_info('skip get value ' || l_col_names(i), l_scope);
                l_json_obj.put_null(l_col_names(i));
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
        logger.log_error('run_sql failed: ' || sqlerrm, l_scope);
        raise;
end run_sql;
/