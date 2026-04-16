-- ============================================================
-- bas_generate_history
-- Generate 24 months of historical allocation data
-- Port of TypeScript generateHistory() with seededRandom(42)
-- ============================================================
create or replace procedure bas_generate_history
as
    -- ---------------------------------------------------------
    -- Seeded LCG: seed = (seed * 1103515245 + 12345) & 0x7fffffff
    -- PL/SQL has no unsigned 32-bit, so use MOD 2^31 (= 2147483648)
    -- to reproduce the JS bitwise & 0x7fffffff behaviour.
    -- ---------------------------------------------------------
    v_seed          number := 42;
    v_modulus       constant number := 2147483648; -- 0x80000000

    -- Category row
    type t_cat is record (
        id              bas_budget_categories.id%type,
        default_percent bas_budget_categories.default_percent%type,
        trend_per_month bas_budget_categories.trend_per_month%type
    );
    type t_cat_tab is table of t_cat index by pls_integer;
    v_cats          t_cat_tab;

    -- Raw allocation accumulator per month
    type t_alloc is table of number index by varchar2(100);
    v_raw_alloc     t_alloc;

    v_month_date    date;
    v_month_str     varchar2(7);   -- 'YYYY-MM'
    v_month_id      bas_historical_months.id%type;
    v_months_from_start number;
    v_trend         number;
    v_noise         number;
    v_raw           number;
    v_total         number;
    v_cat_id        varchar2(100);
    v_rnd           number;        -- value in [0, 1)

    -- ---------------------------------------------------------
    -- Inner function: advance seed and return value in [0, 1)
    -- Matches JS: seed = (seed * 1103515245 + 12345) & 0x7fffffff
    --             return seed / 0x7fffffff
    -- ---------------------------------------------------------
    function seeded_random return number
    as
    begin
        v_seed := mod(v_seed * 1103515245 + 12345, v_modulus);
        return v_seed / 2147483647; -- 0x7fffffff
    end seeded_random;

begin
    -- Load all categories once
    select id, default_percent, nvl(trend_per_month, 0)
    bulk collect into v_cats
    from bas_budget_categories
    order by id;

    if v_cats.count = 0 then
        raise_application_error(-20001, 'bas_budget_categories is empty');
    end if;

    -- Month loop: i = 23 downto 0  (24 months ending this month)
    for i in reverse 0..23 loop

        v_months_from_start := 23 - i;
        v_month_date := add_months(trunc(sysdate, 'MM'), -i);
        v_month_str  := to_char(v_month_date, 'YYYY-MM');

        -- Upsert into bas_historical_months
        begin
            insert into bas_historical_months (month)
            values (v_month_str)
            returning id into v_month_id;
        exception
            when dup_val_on_index then
                select id into v_month_id
                from   bas_historical_months
                where  month = v_month_str;
        end;

        -- Delete existing allocations for idempotency
        delete from bas_historical_month_allocations
        where  month_id = v_month_id;

        v_raw_alloc.delete;
        v_total := 0;

        -- Category loop: compute raw allocations
        for j in 1..v_cats.count loop
            v_rnd  := seeded_random();

            v_trend := v_months_from_start * v_cats(j).trend_per_month;
            -- noise = (random() - 0.5) * 3  =>  range ±1.5
            v_noise := (v_rnd - 0.5) * 3;

            v_raw := greatest(0,
                        least(100,
                              v_cats(j).default_percent + v_trend + v_noise));

            v_raw_alloc(v_cats(j).id) := v_raw;
            v_total := v_total + v_raw;
        end loop;

        -- Normalize to 100% and insert
        -- JS: Math.round(raw / total * 1000) / 10
        v_cat_id := v_raw_alloc.first;
        while v_cat_id is not null loop
            insert into bas_historical_month_allocations
                (month_id, category_id, allocation)
            values (
                v_month_id,
                v_cat_id,
                round(v_raw_alloc(v_cat_id) / v_total * 1000) / 10
            );
            v_cat_id := v_raw_alloc.next(v_cat_id);
        end loop;

    end loop;

    commit;
end bas_generate_history;
/