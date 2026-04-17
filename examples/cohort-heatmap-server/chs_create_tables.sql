-- ============================================================
-- Cohort Heatmap Application Table Definitions for Oracle Database
-- Port of cohort-heatmap-server/server.ts (Zod schemas)
-- ============================================================

-- ------------------------------------------------------------
-- 1. chs_metric_params
--    Internal RetentionParams keyed by metric name
--    (paramsMap in TypeScript: retention / revenue / active)
-- ------------------------------------------------------------
create table chs_metric_params (
    metric           varchar2(20)    not null,
    base_retention   number(10, 4)   not null,
    decay_rate       number(10, 4)   not null,
    floor_value      number(10, 4)   not null,
    noise            number(10, 4)   not null,
    constraint chs_pk_metric_params primary key (metric),
    constraint chs_ck_metric_name
        check (metric in ('retention', 'revenue', 'active'))
);

-- ------------------------------------------------------------
-- 2. chs_dataset_meta
--    CohortDataSchema scalar fields: metric, periodType, generatedAt
-- ------------------------------------------------------------
create table chs_dataset_meta (
    id               number          generated always as identity,
    metric           varchar2(20)    not null,
    period_type      varchar2(20)    not null,
    generated_at     timestamp       default systimestamp not null,
    constraint chs_pk_dataset_meta primary key (id),
    constraint chs_fk_meta_metric foreign key (metric)
        references chs_metric_params (metric),
    constraint chs_ck_period_type
        check (period_type in ('monthly', 'weekly'))
);

-- ------------------------------------------------------------
-- 3. chs_periods
--    CohortDataSchema.periods[] / CohortDataSchema.periodLabels[]
-- ------------------------------------------------------------
create table chs_periods (
    period_index     number          not null,
    period_code      varchar2(10)    not null,
    period_label     varchar2(50)    not null,
    constraint chs_pk_periods primary key (period_index)
);

-- ------------------------------------------------------------
-- 4. chs_cohorts
--    CohortRowSchema (parent): cohortId, cohortLabel, originalUsers
-- ------------------------------------------------------------
create table chs_cohorts (
    cohort_index     number          not null,
    cohort_id        varchar2(20)    not null,
    cohort_label     varchar2(50)    not null,
    original_users   number          not null,
    constraint chs_pk_cohorts primary key (cohort_index)
);

-- ------------------------------------------------------------
-- 5. chs_cohort_cells
--    CohortRowSchema.cells[] = CohortCellSchema
-- ------------------------------------------------------------
create table chs_cohort_cells (
    cohort_index     number          not null,
    period_index     number          not null,
    retention        number(10, 6)   not null,
    users_retained   number          not null,
    users_original   number          not null,
    constraint chs_pk_cohort_cells primary key (cohort_index, period_index),
    constraint chs_fk_cells_cohort foreign key (cohort_index)
        references chs_cohorts (cohort_index) on delete cascade
);

-- ============================================================
-- Comments
-- ============================================================
comment on table chs_metric_params   is 'RetentionParams per metric (paramsMap)';
comment on table chs_dataset_meta    is 'CohortDataSchema scalar fields';
comment on table chs_periods         is 'CohortDataSchema.periods[] / periodLabels[]';
comment on table chs_cohorts         is 'CohortRowSchema parent';
comment on table chs_cohort_cells    is 'CohortRowSchema.cells[] = CohortCellSchema';
