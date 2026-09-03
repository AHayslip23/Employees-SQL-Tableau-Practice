SELECT * FROM employees_staging;

--change data type for age from text to integer
ALTER table employees_staging
ALTER column age TYPE integer using age::integer; 

--handle null values in salary
SELECT
COUNT(CASE WHEN TRIM(salary) = 'N/A' THEN 1 END) as na_count,
ROUND(COUNT(CASE WHEN TRIM(salary) = 'N/A' THEN 1 END) * 100.0 / COUNT(*),
2
) as na_percentage
FROM employees_staging;

DELETE FROM employees_staging
WHERE TRIM(salary) = 'N/A'
OR salary IS NULL;

--change data type for salary from text to integer 
ALTER table employees_staging
ALTER column salary TYPE FLOAT using salary::float;

--handle the null values for employees age 
SELECT 
COUNT(CASE WHEN age IS NULL THEN 1 END) as na_count,
ROUND(
COUNT(CASE WHen Age is null then 1 end) * 100.0 / COUNT(*),
2
) as na_percentage
FROM employees_staging;

--split up department and region into two seperate categories 
--department_region should be department region

SELECT 
department_region,
split_part(department_region, '-', 1) as department,
split_part(department_region, '-', 2) as region
FROM employees_staging;

ALTER TABLE employees_staging
ADD Column department VARCHAR(100),
ADD Column region VARCHAR(100);

UPDATE employees_staging
SET 
department = TRIM(split_part(department_region, '-', 1)),
region = TRIM(split_part(department_region, '-', 2));

ALTER Table employees_staging
DROP column department_region;

--drop employee_id, email, phone
ALTER Table employees_staging
DROP column employee_id,
DROP column email,
DROP column phone;

ALTER Table employees_staging
DROP COLUMN first_name,
DROP COLUMN last_name;

--change data type for remote work column to boolean
ALTER table employees_staging
ALTER column remote_work TYPE boolean using remote_work::boolean;

--chnage data type for join date column to Date
ALTER Table employees_staging
ALTER column join_date TYPE DATE
USING (
CASE
WHEN TRIM(join_date) IN ('N/A', '', '[null]') THEN null
ELSE TO_DATE(join_date, 'FMMM/FMDD/YYYY')
END
);

--create new columns year and month year 
ALTER Table employees_staging
add column year integer,
add column month_year text;

UPDATE employees_staging
set year = extract(year from join_date),
month_year = TO_CHAR(join_date, 'Mon YYYY');

--change name of region to state
ALTER TABLE employees_staging
RENAME column region TO state_name;

--SQL function 
SELECT state_name, COUNT(state_name) as count_of_values
FROM employees_staging
GROUP BY state_name
ORDER BY count_of_values DESC;

--turn values of state name into region by state
CREATE OR REPLACE FUNCTION get_region_by_state(state_name VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    cleaned_state VARCHAR;
    region_output VARCHAR;
BEGIN
    cleaned_state := LOWER(TRIM(state_name));

    CASE
        WHEN cleaned_state IN ('california', 'nevada') THEN
            region_output := 'West';
        WHEN cleaned_state = 'illinois' THEN
            region_output := 'Central';
        WHEN cleaned_state IN ('florida', 'new york') THEN
            region_output := 'East';
        WHEN cleaned_state = 'texas' THEN
            region_output := 'South';
        ELSE
            region_output := 'Other';
    END CASE;

    RETURN region_output;
END;
$$ LANGUAGE plpgsql;

ALTER Table employees_staging ADD column region TEXT;
update employees_staging
SET region = get_region_by_state(state_name);

--create a function that generates a column with income level 
CREATE or REPLACE FUNCTION get_income_level(salary NUMERIC)
RETURNS VARCHAR as $$
DECLARE
income_output VARCHAR;
BEGIN
CASE
WHEN salary is null then
income_output := null;
when salary < 70000 THEN
income_output := 'Low Income';
WHEN salary < 100000 THEN
income_output := 'Medium Income';
ELSE
income_output := 'High Income';
END CASE;

RETURN income_output;
END;
$$ LANGUAGE plpgsql;

ALTER Table employees_staging ADD column income_level text

UPDATE employees_staging
set income_level = get_income_level(salary::NUMERIC);

--create a function for age group by on age values
CREATE or REPLACE FUNCTION get_age_group(age INTEGER)
RETURNS VARCHAR AS $$
DECLARE 
age_group_output VARCHAR;
BEGIN
CASE
WHEN age is null then
age_group_output := NULL;
when age < 30 then age_group_output := '25-29';
WHEN age < 35 THEN age_group_output := '30-34';
WHEN age < 40 THEN age_group_output := '35-39';
ELSE age_group_output := '40+';
END CASE;
RETURN age_group_output;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE employees_staging ADD COLUMN age_group TEXT;
UPDATE employees_staging
set age_group = get_age_group(age);

--check if missingness in age is influenced by salary 
--the missingness in age is not influenced by salary
SELECT
    (age IS NULL) AS age_missing,
    COUNT(*) AS n,
    ROUND(AVG(salary::NUMERIC), 2) AS avg_salary,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary::NUMERIC) AS median_salary
FROM employees_staging
GROUP BY (age IS NULL);

--check that the missingess is contingent 
CREATE OR REPLACE FUNCTION chi2_ln_gamma(x DOUBLE PRECISION) RETURNS DOUBLE PRECISION AS $$
DECLARE
    cof DOUBLE PRECISION[] := ARRAY[76.18009172947146, -86.50532032941677,
        24.01409824083091, -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5];
    y DOUBLE PRECISION := x;
    tmp DOUBLE PRECISION := x + 5.5;
    ser DOUBLE PRECISION := 1.000000000190015;
BEGIN
    tmp := tmp - (x + 0.5) * LN(tmp);
    FOR j IN 1..6 LOOP
        y := y + 1;
        ser := ser + cof[j] / y;
    END LOOP;
    RETURN -tmp + LN(2.5066282746310005 * ser / x);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION chi2_upper_incgamma(a DOUBLE PRECISION, x DOUBLE PRECISION) RETURNS DOUBLE PRECISION AS $$
DECLARE
    gln DOUBLE PRECISION := chi2_ln_gamma(a);
    eps DOUBLE PRECISION := 3e-7;
    fpmin DOUBLE PRECISION := 1e-30;
    b DOUBLE PRECISION; c DOUBLE PRECISION; d DOUBLE PRECISION; h DOUBLE PRECISION;
    an DOUBLE PRECISION; del DOUBLE PRECISION;
    ap DOUBLE PRECISION; sum DOUBLE PRECISION;
BEGIN
    IF x < a + 1 THEN
        -- series expansion for the lower incomplete gamma, then flip
        ap := a; sum := 1.0/a; del := sum;
        FOR n IN 1..200 LOOP
            ap := ap + 1;
            del := del * x / ap;
            sum := sum + del;
            EXIT WHEN ABS(del) < ABS(sum) * eps;
        END LOOP;
        RETURN 1 - (sum * EXP(-x + a*LN(x) - gln));
    ELSE
        -- continued fraction for the upper incomplete gamma
        b := x + 1 - a; c := 1/fpmin; d := 1/b; h := d;
        FOR i IN 1..200 LOOP
            an := -i * (i - a);
            b := b + 2;
            d := an*d + b; IF ABS(d) < fpmin THEN d := fpmin; END IF;
            c := b + an/c; IF ABS(c) < fpmin THEN c := fpmin; END IF;
            d := 1/d;
            del := d*c;
            h := h * del;
            EXIT WHEN ABS(del - 1) < eps;
        END LOOP;
        RETURN EXP(-x + a*LN(x) - gln) * h;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION chi2_pvalue(chi_stat DOUBLE PRECISION, df DOUBLE PRECISION) RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN chi2_upper_incgamma(df/2.0, chi_stat/2.0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

WITH contingency1 AS (
    SELECT
        status,                                                  -- <- change here
        COUNT(CASE WHEN age IS NULL THEN 1 END) AS missing_count,
        COUNT(CASE WHEN age IS NOT NULL THEN 1 END) AS present_count,
        COUNT(*) AS row_total
    FROM employees_staging
    GROUP BY status                                              -- <- and here
),
totals AS (
    SELECT SUM(missing_count) AS total_missing, SUM(present_count) AS total_present,
           SUM(row_total) AS grand_total
    FROM contingency1
),
expected AS (
    SELECT c.missing_count, c.present_count,
        c.row_total * t.total_missing::NUMERIC / t.grand_total AS expected_missing,
        c.row_total * t.total_present::NUMERIC / t.grand_total AS expected_present
    FROM contingency1 c CROSS JOIN totals t
),
stat AS (
    SELECT
        SUM(POWER(missing_count - expected_missing, 2) / expected_missing
          + POWER(present_count - expected_present, 2) / expected_present) AS chi_square,
        (SELECT COUNT(DISTINCT department) FROM employees_staging) - 1 AS df  -- <- and here
    FROM expected
)
SELECT
    'status' AS variable,                                        -- <- and here
    chi_square,
    df,
    chi2_pvalue(chi_square, df) AS p_value
FROM stat;

WITH contingency2 AS (
    SELECT
        performance_score,                                                  -- <- change here
        COUNT(CASE WHEN age IS NULL THEN 1 END) AS missing_count,
        COUNT(CASE WHEN age IS NOT NULL THEN 1 END) AS present_count,
        COUNT(*) AS row_total
    FROM employees_staging
    GROUP BY performance_score                                              -- <- and here
),
totals AS (
    SELECT SUM(missing_count) AS total_missing, SUM(present_count) AS total_present,
           SUM(row_total) AS grand_total
    FROM contingency2
),
expected AS (
    SELECT c.missing_count, c.present_count,
        c.row_total * t.total_missing::NUMERIC / t.grand_total AS expected_missing,
        c.row_total * t.total_present::NUMERIC / t.grand_total AS expected_present
    FROM contingency2 c CROSS JOIN totals t
),
stat AS (
    SELECT
        SUM(POWER(missing_count - expected_missing, 2) / expected_missing
          + POWER(present_count - expected_present, 2) / expected_present) AS chi_square,
        (SELECT COUNT(DISTINCT department) FROM employees_staging) - 1 AS df  -- <- and here
    FROM expected
)
SELECT
    'performance_score' AS variable,                                        -- <- and here
    chi_square,
    df,
    chi2_pvalue(chi_square, df) AS p_value
FROM stat;

WITH contingency3 AS (
    SELECT
        remote_work,                                                  -- <- change here
        COUNT(CASE WHEN age IS NULL THEN 1 END) AS missing_count,
        COUNT(CASE WHEN age IS NOT NULL THEN 1 END) AS present_count,
        COUNT(*) AS row_total
    FROM employees_staging
    GROUP BY remote_work                                             -- <- and here
),
totals AS (
    SELECT SUM(missing_count) AS total_missing, SUM(present_count) AS total_present,
           SUM(row_total) AS grand_total
    FROM contingency3
),
expected AS (
    SELECT c.missing_count, c.present_count,
        c.row_total * t.total_missing::NUMERIC / t.grand_total AS expected_missing,
        c.row_total * t.total_present::NUMERIC / t.grand_total AS expected_present
    FROM contingency3 c CROSS JOIN totals t
),
stat AS (
    SELECT
        SUM(POWER(missing_count - expected_missing, 2) / expected_missing
          + POWER(present_count - expected_present, 2) / expected_present) AS chi_square,
        (SELECT COUNT(DISTINCT department) FROM employees_staging) - 1 AS df  -- <- and here
    FROM expected
)
SELECT
    'remote_work' AS variable,                                        -- <- and here
    chi_square,
    df,
    chi2_pvalue(chi_square, df) AS p_value
FROM stat;

WITH contingency4 AS (
    SELECT
        department,                                                  -- <- change here
        COUNT(CASE WHEN age IS NULL THEN 1 END) AS missing_count,
        COUNT(CASE WHEN age IS NOT NULL THEN 1 END) AS present_count,
        COUNT(*) AS row_total
    FROM employees_staging
    GROUP BY department                                             -- <- and here
),
totals AS (
    SELECT SUM(missing_count) AS total_missing, SUM(present_count) AS total_present,
           SUM(row_total) AS grand_total
    FROM contingency4
),
expected AS (
    SELECT c.missing_count, c.present_count,
        c.row_total * t.total_missing::NUMERIC / t.grand_total AS expected_missing,
        c.row_total * t.total_present::NUMERIC / t.grand_total AS expected_present
    FROM contingency4 c CROSS JOIN totals t
),
stat AS (
    SELECT
        SUM(POWER(missing_count - expected_missing, 2) / expected_missing
          + POWER(present_count - expected_present, 2) / expected_present) AS chi_square,
        (SELECT COUNT(DISTINCT department) FROM employees_staging) - 1 AS df  -- <- and here
    FROM expected
)
SELECT
    'department' AS variable,                                        -- <- and here
    chi_square,
    df,
    chi2_pvalue(chi_square, df) AS p_value
FROM stat;

WITH contingency5 AS (
    SELECT
        state_name,                                                  -- <- change here
        COUNT(CASE WHEN age IS NULL THEN 1 END) AS missing_count,
        COUNT(CASE WHEN age IS NOT NULL THEN 1 END) AS present_count,
        COUNT(*) AS row_total
    FROM employees_staging
    GROUP BY state_name                                             -- <- and here
),
totals AS (
    SELECT SUM(missing_count) AS total_missing, SUM(present_count) AS total_present,
           SUM(row_total) AS grand_total
    FROM contingency5
),
expected AS (
    SELECT c.missing_count, c.present_count,
        c.row_total * t.total_missing::NUMERIC / t.grand_total AS expected_missing,
        c.row_total * t.total_present::NUMERIC / t.grand_total AS expected_present
    FROM contingency5 c CROSS JOIN totals t
),
stat AS (
    SELECT
        SUM(POWER(missing_count - expected_missing, 2) / expected_missing
          + POWER(present_count - expected_present, 2) / expected_present) AS chi_square,
        (SELECT COUNT(DISTINCT department) FROM employees_staging) - 1 AS df  -- <- and here
    FROM expected
)
SELECT
    'state_name' AS variable,                                        -- <- and here
    chi_square,
    df,
    chi2_pvalue(chi_square, df) AS p_value
FROM stat;