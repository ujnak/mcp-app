create or replace function chs_get_cohort_data_response(
    p_parameters in clob default null
) return clob
as
    -- ---------------------------------------------------------
    -- Parsed inputs (defaults mirror input_schema.json)
    -- ---------------------------------------------------------
    l_params         json_object_t;
    l_metric         varchar2(20)  := 'retention';
    l_period_type    varchar2(20)  := 'monthly';
    l_cohort_count   number        := 12;
    l_max_periods    number        := 12;

    -- root wrapper: { content: [...], structuredContent: data }
    l_root           json_object_t := json_object_t();
    l_content        json_array_t  := json_array_t();
    l_content_item   json_object_t;

    -- structuredContent = CohortData
    l_data           json_object_t := json_object_t();

    -- cohorts[]
    l_cohorts        json_array_t  := json_array_t();
    l_cohort_obj     json_object_t;
    l_cells          json_array_t;
    l_cell           json_object_t;

    -- periods[] / periodLabels[]
    l_periods        json_array_t  := json_array_t();
    l_period_labels  json_array_t  := json_array_t();

    -- meta
    l_meta_metric    chs_dataset_meta.metric%type;
    l_meta_period    chs_dataset_meta.period_type%type;
    l_generated_at   chs_dataset_meta.generated_at%type;

    -- formatCohortSummary() locals
    l_n_cohorts      number;
    l_n_periods      number;
    l_avg_retention  number;
    l_pct_str        varchar2(50);
    l_summary_text   varchar2(4000);
begin
    -- ============================================================
    -- Parse p_parameters per input_schema.json
    -- (GetCohortDataInput: metric / periodType / cohortCount / maxPeriods)
    -- All fields are optional; missing fields fall back to defaults.
    -- ============================================================
    if p_parameters is not null and dbms_lob.getlength(p_parameters) > 0 then
        l_params := json_object_t.parse(p_parameters);

        if l_params.has('metric') then
            l_metric := l_params.get_string('metric');
        end if;
        if l_params.has('periodType') then
            l_period_type := l_params.get_string('periodType');
        end if;
        if l_params.has('cohortCount') then
            l_cohort_count := l_params.get_number('cohortCount');
        end if;
        if l_params.has('maxPeriods') then
            l_max_periods := l_params.get_number('maxPeriods');
        end if;
    end if;

    -- ============================================================
    -- Validate against input_schema constraints
    -- ============================================================
    if l_metric not in ('retention', 'revenue', 'active') then
        raise_application_error(-20002,
            'metric must be one of: retention, revenue, active');
    end if;
    if l_period_type not in ('monthly', 'weekly') then
        raise_application_error(-20003,
            'periodType must be one of: monthly, weekly');
    end if;
    if l_cohort_count < 3 or l_cohort_count > 24 then
        raise_application_error(-20004,
            'cohortCount must be between 3 and 24');
    end if;
    if l_max_periods < 3 or l_max_periods > 24 then
        raise_application_error(-20005,
            'maxPeriods must be between 3 and 24');
    end if;

    -- ============================================================
    -- Re-generate the dataset with the requested parameters.
    -- chs_generate_cohort_data commits internally.
    -- ============================================================
    chs_generate_cohort_data(
        p_metric       => l_metric,
        p_period_type  => l_period_type,
        p_cohort_count => l_cohort_count,
        p_max_periods  => l_max_periods
    );

    -- ============================================================
    -- meta: metric / periodType / generatedAt
    -- ============================================================
    select metric, period_type, generated_at
    into   l_meta_metric, l_meta_period, l_generated_at
    from   chs_dataset_meta
    fetch first 1 rows only;

    -- ============================================================
    -- periods[] and periodLabels[]
    -- ============================================================
    for r in (
        select period_code, period_label
        from   chs_periods
        order  by period_index
    ) loop
        l_periods.append(r.period_code);
        l_period_labels.append(r.period_label);
    end loop;

    -- ============================================================
    -- cohorts[] (with nested cells[])
    -- ============================================================
    for ch in (
        select cohort_index, cohort_id, cohort_label, original_users
        from   chs_cohorts
        order  by cohort_index
    ) loop
        l_cohort_obj := json_object_t();
        l_cells      := json_array_t();

        for cell in (
            select cohort_index, period_index, retention,
                   users_retained, users_original
            from   chs_cohort_cells
            where  cohort_index = ch.cohort_index
            order  by period_index
        ) loop
            l_cell := json_object_t();
            l_cell.put('cohortIndex',   cell.cohort_index);
            l_cell.put('periodIndex',   cell.period_index);
            l_cell.put('retention',     cell.retention);
            l_cell.put('usersRetained', cell.users_retained);
            l_cell.put('usersOriginal', cell.users_original);
            l_cells.append(l_cell);
        end loop;

        l_cohort_obj.put('cohortId',      ch.cohort_id);
        l_cohort_obj.put('cohortLabel',   ch.cohort_label);
        l_cohort_obj.put('originalUsers', ch.original_users);
        l_cohort_obj.put('cells',         l_cells);
        l_cohorts.append(l_cohort_obj);
    end loop;

    -- ============================================================
    -- Build structuredContent (CohortData)
    -- ============================================================
    l_data.put('cohorts',      l_cohorts);
    l_data.put('periods',      l_periods);
    l_data.put('periodLabels', l_period_labels);
    l_data.put('metric',       l_meta_metric);
    l_data.put('periodType',   l_meta_period);
    l_data.put(
        'generatedAt',
        to_char(
            l_generated_at at time zone 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'
        )
    );

    -- ============================================================
    -- formatCohortSummary(data)
    -- Port of TypeScript:
    --   const avgRetention = data.cohorts
    --     .flatMap((c) => c.cells)
    --     .filter((cell) => cell.periodIndex > 0)
    --     .reduce((sum, cell, _, arr) => sum + cell.retention / arr.length, 0);
    --   `Cohort Analysis: ${cohorts.length} cohorts, ${periods.length} periods
    --    Average retention: ${(avgRetention * 100).toFixed(1)}%
    --    Metric: ${metric}, Period: ${periodType}`
    -- ============================================================
    select count(*) into l_n_cohorts from chs_cohorts;
    select count(*) into l_n_periods from chs_periods;
    select nvl(avg(retention), 0)
      into l_avg_retention
      from chs_cohort_cells
     where period_index > 0;

    -- toFixed(1) equivalent: round to 1 decimal, force unit digit
    l_pct_str := trim(to_char(round(l_avg_retention * 100, 1), '99990.0'));

    l_summary_text :=
        'Cohort Analysis: ' || l_n_cohorts || ' cohorts, '
            || l_n_periods || ' periods' || chr(10) ||
        'Average retention: ' || l_pct_str || '%' || chr(10) ||
        'Metric: ' || l_meta_metric || ', Period: ' || l_meta_period;

    -- ============================================================
    -- content[0] = { type: "text", text: formatCohortSummary(data) }
    -- ============================================================
    l_content_item := json_object_t();
    l_content_item.put('type', 'text');
    l_content_item.put('text', l_summary_text);
    l_content.append(l_content_item);

    -- ============================================================
    -- root = { content: [...], structuredContent: data }
    -- ============================================================
    l_root.put('content',           l_content);
    l_root.put('structuredContent', l_data);

    return l_root.to_clob();
end chs_get_cohort_data_response;
/
