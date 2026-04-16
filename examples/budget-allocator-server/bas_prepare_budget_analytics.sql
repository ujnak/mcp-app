declare
    l_analytics_id bas_budget_analytics.id%type;
    l_sb_id        bas_stage_benchmarks.id%type;
begin
    -- ============================================================
    -- 1. bas_budget_analytics (parent record)
    -- ============================================================
    insert into bas_budget_analytics (default_stage)
    values ('Seed')
    returning id into l_analytics_id;

    -- ============================================================
    -- 2. bas_budget_analytics_stages
    -- ============================================================
    insert into bas_budget_analytics_stages (analytics_id, sort_order, stage_name)
    values (l_analytics_id, 1, 'Seed');

    insert into bas_budget_analytics_stages (analytics_id, sort_order, stage_name)
    values (l_analytics_id, 2, 'Series A');

    insert into bas_budget_analytics_stages (analytics_id, sort_order, stage_name)
    values (l_analytics_id, 3, 'Series B');

    insert into bas_budget_analytics_stages (analytics_id, sort_order, stage_name)
    values (l_analytics_id, 4, 'Growth');

    -- ============================================================
    -- 3. bas_stage_benchmarks + bas_stage_benchmark_percentiles
    -- ============================================================

    -- Seed
    insert into bas_stage_benchmarks (analytics_id, stage)
    values (l_analytics_id, 'Seed')
    returning id into l_sb_id;

    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'marketing',   15, 20, 25);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'engineering', 40, 47, 55);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'operations',   8, 12, 15);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'sales',       10, 15, 20);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'rd',           5, 10, 15);

    -- Series A
    insert into bas_stage_benchmarks (analytics_id, stage)
    values (l_analytics_id, 'Series A')
    returning id into l_sb_id;

    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'marketing',   20, 25, 30);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'engineering', 35, 40, 45);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'operations',  10, 14, 18);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'sales',       15, 20, 25);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'rd',           8, 12, 15);

    -- Series B
    insert into bas_stage_benchmarks (analytics_id, stage)
    values (l_analytics_id, 'Series B')
    returning id into l_sb_id;

    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'marketing',   22, 27, 32);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'engineering', 30, 35, 40);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'operations',  12, 16, 20);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'sales',       18, 23, 28);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'rd',           8, 12, 15);

    -- Growth
    insert into bas_stage_benchmarks (analytics_id, stage)
    values (l_analytics_id, 'Growth')
    returning id into l_sb_id;

    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'marketing',   25, 30, 35);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'engineering', 25, 30, 35);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'operations',  15, 18, 22);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'sales',       20, 25, 30);
    insert into bas_stage_benchmark_percentiles (benchmark_id, category_id, p25, p50, p75)
    values (l_sb_id, 'rd',           5,  8, 12);

    commit;
end;
/