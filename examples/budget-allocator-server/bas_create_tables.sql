-- ============================================================
-- Budget Application Table Definitions for Oracle Database
-- ============================================================

-- ------------------------------------------------------------
-- 1. bas_budget_categories
--    BudgetCategorySchema + BudgetCategoryInternal
-- ------------------------------------------------------------
create table bas_budget_categories (
    id               varchar2(100)   not null,
    name             varchar2(200)   not null,
    color            varchar2(50)    not null,
    default_percent  number(10, 4)   not null,
    trend_per_month  number(10, 4),
    constraint bas_pk_budget_categories primary key (id)
);

-- ------------------------------------------------------------
-- 2. bas_budget_config
--    BudgetConfigSchema (scalar fields)
-- ------------------------------------------------------------
create table bas_budget_config (
    id               number          generated always as identity,
    default_budget   number(15, 4)   not null,
    currency         varchar2(10)    not null,
    currency_symbol  varchar2(10)    not null,
    constraint bas_pk_budget_config primary key (id)
);

-- ------------------------------------------------------------
-- 3. bas_budget_config_preset_budgets
--    BudgetConfigSchema.presetBudgets: z.array(z.number())
-- ------------------------------------------------------------
create table bas_budget_config_preset_budgets (
    id               number          generated always as identity,
    config_id        number          not null,
    sort_order       number          not null,
    preset_value     number(15, 4)   not null,
    constraint bas_pk_config_presets    primary key (id),
    constraint bas_fk_presets_config    foreign key (config_id)
        references bas_budget_config (id) on delete cascade
);

-- ------------------------------------------------------------
-- 4. bas_historical_months
--    HistoricalMonthSchema (parent)
-- ------------------------------------------------------------
create table bas_historical_months (
    id               number          generated always as identity,
    month            varchar2(20)    not null,
    constraint bas_pk_historical_months primary key (id),
    constraint bas_uq_historical_months unique (month)
);

-- ------------------------------------------------------------
-- 5. bas_historical_month_allocations
--    HistoricalMonthSchema.allocations: z.record(z.string(), z.number())
-- ------------------------------------------------------------
create table bas_historical_month_allocations (
    id               number          generated always as identity,
    month_id         number          not null,
    category_id      varchar2(100)   not null,
    allocation       number(15, 4)   not null,
    constraint bas_pk_hma               primary key (id),
    constraint bas_fk_hma_month         foreign key (month_id)
        references bas_historical_months (id) on delete cascade,
    constraint bas_uq_hma_month_cat     unique (month_id, category_id)
);

-- ------------------------------------------------------------
-- 6. bas_budget_analytics
--    BudgetAnalyticsSchema (scalar fields)
-- ------------------------------------------------------------
create table bas_budget_analytics (
    id               number          generated always as identity,
    default_stage    varchar2(200)   not null,
    constraint bas_pk_budget_analytics  primary key (id)
);

-- ------------------------------------------------------------
-- 7. bas_budget_analytics_stages
--    BudgetAnalyticsSchema.stages: z.array(z.string())
-- ------------------------------------------------------------
create table bas_budget_analytics_stages (
    id               number          generated always as identity,
    analytics_id     number          not null,
    sort_order       number          not null,
    stage_name       varchar2(200)   not null,
    constraint bas_pk_analytics_stages  primary key (id),
    constraint bas_fk_stages_analytics  foreign key (analytics_id)
        references bas_budget_analytics (id) on delete cascade
);

-- ------------------------------------------------------------
-- 8. bas_stage_benchmarks
--    StageBenchmarkSchema (parent)
-- ------------------------------------------------------------
create table bas_stage_benchmarks (
    id               number          generated always as identity,
    analytics_id     number          not null,
    stage            varchar2(200)   not null,
    constraint bas_pk_stage_benchmarks  primary key (id),
    constraint bas_fk_sb_analytics      foreign key (analytics_id)
        references bas_budget_analytics (id) on delete cascade,
    constraint bas_uq_sb_analytics_stage unique (analytics_id, stage)
);

-- ------------------------------------------------------------
-- 9. bas_stage_benchmark_percentiles
--    StageBenchmarkSchema.categoryBenchmarks:
--      z.record(z.string(), BenchmarkPercentilesSchema)
-- ------------------------------------------------------------
create table bas_stage_benchmark_percentiles (
    id               number          generated always as identity,
    benchmark_id     number          not null,
    category_id      varchar2(100)   not null,
    p25              number(10, 4)   not null,
    p50              number(10, 4)   not null,
    p75              number(10, 4)   not null,
    constraint bas_pk_sbp               primary key (id),
    constraint bas_fk_sbp_benchmark     foreign key (benchmark_id)
        references bas_stage_benchmarks (id) on delete cascade,
    constraint bas_uq_sbp_bench_cat     unique (benchmark_id, category_id)
);

-- ============================================================
-- Comments
-- ============================================================
comment on table bas_budget_categories              is 'BudgetCategorySchema / BudgetCategoryInternal';
comment on table bas_budget_config                  is 'BudgetConfigSchema scalar fields';
comment on table bas_budget_config_preset_budgets   is 'BudgetConfigSchema.presetBudgets[]';
comment on table bas_historical_months              is 'HistoricalMonthSchema parent';
comment on table bas_historical_month_allocations   is 'HistoricalMonthSchema.allocations record';
comment on table bas_budget_analytics               is 'BudgetAnalyticsSchema scalar fields';
comment on table bas_budget_analytics_stages        is 'BudgetAnalyticsSchema.stages[]';
comment on table bas_stage_benchmarks               is 'StageBenchmarkSchema parent';
comment on table bas_stage_benchmark_percentiles    is 'StageBenchmarkSchema.categoryBenchmarks record → BenchmarkPercentilesSchema';