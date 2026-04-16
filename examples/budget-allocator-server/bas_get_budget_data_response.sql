create or replace function bas_get_budget_data_response
    return clob
as
    -- root
    l_root              json_object_t := json_object_t();

    -- config
    l_config            json_object_t := json_object_t();
    l_categories        json_array_t  := json_array_t();
    l_category          json_object_t;
    l_presets           json_array_t  := json_array_t();

    -- analytics
    l_analytics         json_object_t := json_object_t();
    l_history           json_array_t  := json_array_t();
    l_month_obj         json_object_t;
    l_allocations       json_object_t;
    l_benchmarks        json_array_t  := json_array_t();
    l_benchmark_obj     json_object_t;
    l_cat_benchmarks    json_object_t;
    l_percentiles       json_object_t;
    l_stages            json_array_t  := json_array_t();

    -- work
    l_analytics_id      bas_budget_analytics.id%type;
    l_default_stage     bas_budget_analytics.default_stage%type;
begin
    -- ============================================================
    -- config.categories
    -- trendPerMonth は BudgetCategorySchema 外のため除外
    -- ============================================================
    for r in (
        select id, name, color, default_percent
        from   bas_budget_categories
        order  by id
    ) loop
        l_category := json_object_t();
        l_category.put('id',             r.id);
        l_category.put('name',           r.name);
        l_category.put('color',          r.color);
        l_category.put('defaultPercent', r.default_percent);
        l_categories.append(l_category);
    end loop;

    -- ============================================================
    -- config.presetBudgets
    -- ============================================================
    for r in (
        select preset_value
        from   bas_budget_config_preset_budgets
        where  config_id = (select id from bas_budget_config fetch first 1 rows only)
        order  by sort_order
    ) loop
        l_presets.append(r.preset_value);
    end loop;

    -- ============================================================
    -- config
    -- ============================================================
    for r in (
        select default_budget, currency, currency_symbol
        from   bas_budget_config
        fetch first 1 rows only
    ) loop
        l_config.put('categories',     l_categories);
        l_config.put('presetBudgets',  l_presets);
        l_config.put('defaultBudget',  r.default_budget);
        l_config.put('currency',       r.currency);
        l_config.put('currencySymbol', r.currency_symbol);
    end loop;

    -- ============================================================
    -- analytics parent
    -- ============================================================
    select id, default_stage
    into   l_analytics_id, l_default_stage
    from   bas_budget_analytics
    fetch first 1 rows only;

    -- ============================================================
    -- analytics.history
    -- ============================================================
    for hm in (
        select id, month
        from   bas_historical_months
        order  by month
    ) loop
        l_month_obj   := json_object_t();
        l_allocations := json_object_t();

        for hma in (
            select category_id, allocation
            from   bas_historical_month_allocations
            where  month_id = hm.id
        ) loop
            l_allocations.put(hma.category_id, hma.allocation);
        end loop;

        l_month_obj.put('month',       hm.month);
        l_month_obj.put('allocations', l_allocations);
        l_history.append(l_month_obj);
    end loop;

    -- ============================================================
    -- analytics.benchmarks
    -- ============================================================
    for sb in (
        select id, stage
        from   bas_stage_benchmarks
        where  analytics_id = l_analytics_id
        order  by id
    ) loop
        l_benchmark_obj  := json_object_t();
        l_cat_benchmarks := json_object_t();

        for sbp in (
            select category_id, p25, p50, p75
            from   bas_stage_benchmark_percentiles
            where  benchmark_id = sb.id
        ) loop
            l_percentiles := json_object_t();
            l_percentiles.put('p25', sbp.p25);
            l_percentiles.put('p50', sbp.p50);
            l_percentiles.put('p75', sbp.p75);
            l_cat_benchmarks.put(sbp.category_id, l_percentiles);
        end loop;

        l_benchmark_obj.put('stage',              sb.stage);
        l_benchmark_obj.put('categoryBenchmarks', l_cat_benchmarks);
        l_benchmarks.append(l_benchmark_obj);
    end loop;

    -- ============================================================
    -- analytics.stages
    -- ============================================================
    for r in (
        select stage_name
        from   bas_budget_analytics_stages
        where  analytics_id = l_analytics_id
        order  by sort_order
    ) loop
        l_stages.append(r.stage_name);
    end loop;

    -- ============================================================
    -- analytics
    -- ============================================================
    l_analytics.put('history',      l_history);
    l_analytics.put('benchmarks',   l_benchmarks);
    l_analytics.put('stages',       l_stages);
    l_analytics.put('defaultStage', l_default_stage);

    -- ============================================================
    -- BudgetDataResponse (root)
    -- ============================================================
    l_root.put('config',    l_config);
    l_root.put('analytics', l_analytics);

    return l_root.to_clob();
end bas_get_budget_data_response;
/
