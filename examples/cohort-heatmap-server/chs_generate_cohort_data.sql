-- ============================================================
-- chs_generate_cohort_data
-- Port of TypeScript generateCohortData() / generateRetention()
-- Uses seeded LCG (seed = 42) for deterministic output, matching
-- the bas_generate_history convention.
-- ============================================================
create or replace procedure chs_generate_cohort_data(
    p_metric        in varchar2 default 'retention',
    p_period_type   in varchar2 default 'monthly',
    p_cohort_count  in number   default 12,
    p_max_periods   in number   default 12
)
as
    -- ---------------------------------------------------------
    -- Seeded LCG (matches bas_generate_history)
    -- seed = (seed * 1103515245 + 12345) mod 2^31
    -- ---------------------------------------------------------
    v_seed       number := 42;
    v_modulus    constant number := 2147483648; -- 0x80000000

    -- RetentionParams loaded from chs_metric_params
    v_base_ret   chs_metric_params.base_retention%type;
    v_decay      chs_metric_params.decay_rate%type;
    v_floor      chs_metric_params.floor_value%type;
    v_noise_p    chs_metric_params.noise%type;

    -- Loop locals
    v_cohort_date    date;
    v_cohort_id      varchar2(20);
    v_cohort_label   varchar2(50);
    v_original       number;
    v_periods_avail  number;
    v_p_max          number;
    v_retention      number;
    v_prev_ret       number;
    v_base           number;
    v_variation      number;
    v_rnd            number;

    -- ---------------------------------------------------------
    -- Inner: advance seed and return value in [0, 1)
    -- ---------------------------------------------------------
    function seeded_random return number
    as
    begin
        v_seed := mod(v_seed * 1103515245 + 12345, v_modulus);
        return v_seed / 2147483647; -- 0x7fffffff
    end seeded_random;

begin
    -- Load metric params (raises NO_DATA_FOUND if metric is unknown)
    select base_retention, decay_rate, floor_value, noise
    into   v_base_ret, v_decay, v_floor, v_noise_p
    from   chs_metric_params
    where  metric = p_metric;

    -- Idempotent reset (cells deleted via FK cascade)
    delete from chs_cohorts;
    delete from chs_periods;
    delete from chs_dataset_meta;

    -- Insert dataset meta
    insert into chs_dataset_meta (metric, period_type)
    values (p_metric, p_period_type);

    -- ============================================================
    -- Period headers: M0..M(maxPeriods-1) / "Month 0".."Month N"
    -- ============================================================
    for p in 0 .. p_max_periods - 1 loop
        insert into chs_periods (period_index, period_code, period_label)
        values (
            p,
            'M' || p,
            case when p = 0 then 'Month 0' else 'Month ' || p end
        );
    end loop;

    -- ============================================================
    -- Cohorts (oldest first)
    -- ============================================================
    for c in 0 .. p_cohort_count - 1 loop

        v_cohort_date  := add_months(trunc(sysdate, 'MM'), -(p_cohort_count - 1 - c));
        v_cohort_id    := to_char(v_cohort_date, 'YYYY-MM');
        v_cohort_label := to_char(
                              v_cohort_date,
                              'Mon YYYY',
                              'NLS_DATE_LANGUAGE=AMERICAN'
                          );

        -- originalUsers = floor(1000 + random * 4000)
        v_rnd      := seeded_random();
        v_original := floor(1000 + v_rnd * 4000);

        insert into chs_cohorts (cohort_index, cohort_id, cohort_label, original_users)
        values (c, v_cohort_id, v_cohort_label, v_original);

        -- Newer cohorts have fewer periods
        v_periods_avail := p_cohort_count - c;
        v_p_max         := least(v_periods_avail, p_max_periods);
        v_prev_ret      := 1.0;

        for p in 0 .. v_p_max - 1 loop
            -- generateRetention(): period 0 always returns 1.0
            if p = 0 then
                v_retention := 1.0;
            else
                v_rnd       := seeded_random();
                v_base      := v_base_ret * exp(-v_decay * (p - 1)) + v_floor;
                v_variation := (v_rnd - 0.5) * 2 * v_noise_p;
                v_retention := greatest(0, least(1, v_base + v_variation));
            end if;

            -- Retention must not jump above previous + 0.02
            v_retention := least(v_retention, v_prev_ret + 0.02);
            v_prev_ret  := v_retention;

            insert into chs_cohort_cells
                (cohort_index, period_index, retention, users_retained, users_original)
            values (
                c,
                p,
                v_retention,
                round(v_original * v_retention),
                v_original
            );
        end loop;

    end loop;

    commit;
end chs_generate_cohort_data;
/
