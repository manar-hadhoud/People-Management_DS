
-- 6. Identify Managers With the Highest Turnover :the most employees leaving their department DONE
/*
first join to get managers info from employee table
second join to count department employees in each manager group
we have 24 managers then 24 row for each group
*/

SELECT 
    dm.employee_id,
    dm.department_id,
    e.first_name AS manager_first_name,
    e.last_name AS manager_last_name,
    COUNT(DISTINCT de.employee_id) AS employees_left
FROM department_manager dm
JOIN employee e 
    ON dm.employee_id = e.id
JOIN department_employee de
    ON dm.department_id = de.department_id
WHERE de.to_date <> '9999-01-01' -- Only count employees who have left
  AND de.from_date >= dm.from_date -- Employee joined after the manager started
  AND de.to_date <= dm.to_date -- Employee left before the manager ended
GROUP BY dm.employee_id,dm.department_id, e.first_name, e.last_name
ORDER BY employees_left DESC;


--------------------------------------------------------------------------------------------



-- 7. ​Find Employees Who Worked Less Than a Year 3206
-- employees whose duration of employment (difference between hire_date and to_date) < one year.
SELECT 
    e.id, 
    e.first_name, 
    e.last_name, 
    e.hire_date ,
    de.to_date AS date_left, 
    AGE(de.to_date, e.hire_date) AS duration
FROM employee e
JOIN department_employee de 
ON de.employee_id = e.id 
    AND de.to_date = (
        SELECT MAX(de_sub.to_date)   -- TAKE THE LATEST DATE
        FROM department_employee de_sub
        WHERE de_sub.employee_id = de.employee_id
    )
WHERE de.to_date <> '9999-01-01'
    AND AGE(de.to_date, e.hire_date) < INTERVAL '1 year'
  -- AND (EXTRACT(YEAR FROM de.to_date) - EXTRACT(YEAR FROM e.hire_date))< 1 
  -- won't handle cases of months < year in case of 1 year difference


--------------------------------------------------------------------------------



-- 10. Identify the Average Tenure of Employees Who Left     
-- calc  average duration of employment for terminated employees.

SELECT ROUND(AVG(duration_days),4) AS Average_Tenure 
FROM(
    SELECT e.id, e.first_name, e.last_name
    ,e.hire_date,MAX(de.to_date) AS latest_to_date,
    (MAX(de.to_date) - e.hire_date) AS duration_days
    FROM employee e
    JOIN department_employee de
    ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
        AND NOT EXISTS (
          SELECT 1
          FROM department_employee de_active
          WHERE de_active.employee_id = e.id
            AND de_active.to_date = '9999-01-01'
      )
    GROUP BY e.id, e.first_name, e.last_name, e.hire_date
) AS terminated_employees;


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

-- 13. Classify Employee Tenure DONE
-- Employee tenure refers to the length of time an employee has been working at a company
-- CASE statement to categorize employee tenure into 
-- "Short-Term" (<1 year), 
-- "Mid-Term" (1-3 years), 
-- "Long-Term" (>3 years).

WITH LatestDepartment AS (
    SELECT 
        de.employee_id,
        MAX(de.to_date) AS latest_to_date
    FROM department_employee de
    GROUP BY de.employee_id
),
ClassifiedEmployees AS (
    SELECT 
        e.id AS employee_id,
        e.first_name,
        e.last_name,
        e.hire_date,
        ld.latest_to_date,
        AGE(ld.latest_to_date, e.hire_date) AS tenure_duration,
        CASE
            WHEN AGE(ld.latest_to_date, e.hire_date) < INTERVAL '1 year' THEN 'Short-Term'
            WHEN AGE(ld.latest_to_date, e.hire_date) BETWEEN INTERVAL '1 year' AND INTERVAL '3 years' THEN 'Mid-Term'
            ELSE 'Long-Term'
        END AS tenure_category
    FROM employee e
    JOIN LatestDepartment ld
    ON e.id = ld.employee_id
    WHERE ld.latest_to_date < CURRENT_DATE -- Exclude employees still active (to ask if still working included)
)
SELECT 
    employee_id,
    first_name,
    last_name,
    hire_date,
    latest_to_date,
    tenure_duration,
    tenure_category
FROM ClassifiedEmployees
ORDER BY employee_id;
--LIMIT 10000;


---------------------------------------------------------------------------------------------------

-- 14. Label Employees Who Left Due to Churn 
-- Use a CASE statement to mark employees as "Churned" or "Retired" based on to_date and age.


WITH LatestDate AS (
    SELECT 
        DISTINCT de.employee_id,
        MAX(de.to_date) AS latest_to_date
    FROM department_employee de
    WHERE de.to_date < CURRENT_DATE -- Only consider terminated
        AND NOT EXISTS (
          SELECT 1
          FROM department_employee de_active
          WHERE de_active.employee_id = de.employee_id
            AND de_active.to_date = '9999-01-01'
      )
    GROUP BY de.employee_id
)
SELECT 
    e.id AS employee_id,
    e.first_name,
    e.last_name,
    e.birth_date,
    ld.latest_to_date,
    CASE
        WHEN EXTRACT(YEAR FROM AGE(ld.latest_to_date, e.birth_date)) >= 60 THEN 'Retired'
        ELSE 'Churned'
    END AS employee_status
FROM employee e
INNER JOIN LatestDate ld
ON e.id = ld.employee_id


-------------------------------------------------------------------------------------



-- 17. Find Average Time to Termination for Employees by Department
-- Calculate the average time (in days) from hire_date to to_date for terminated employees, 
-- grouped by department.
--with average_time_to_termination AS (

SELECT 
    de.department_id,
    d.dept_name,
    AVG( EXTRACT(DAY FROM AGE(de.to_date , de.from_date))) AS average_time_to_termination  -- to ask which to use from_date or hire_date
FROM department_employee de
JOIN department d
    ON de.department_id = d.id
WHERE de.to_date <> '9999-01-01'
GROUP BY de.department_id,d.dept_name
ORDER BY average_time_to_termination;



----------------------------------------------------------------------------




-- 17. Find Average Time to Termination for Employees by Department
-- Calculate the average time (in days) from hire_date to to_date for terminated employees, 
-- grouped by department.
--with average_time_to_termination AS (

SELECT 
    de.department_id,
    d.dept_name,
    AVG( EXTRACT(DAY FROM AGE(de.to_date , de.from_date))) AS average_time_to_termination  -- to ask which to use from_date or hire_date
FROM department_employee de
JOIN department d
    ON de.department_id = d.id
WHERE de.to_date <> '9999-01-01'
GROUP BY de.department_id,d.dept_name
ORDER BY average_time_to_termination;

----------------------------------------------------------------------------------------------

-- 18. Analyze Churn vs. Hiring Trends
-- Compare the number of employees hired vs. terminated over a given time period.
-- time period example 

-- Hires: Count employees hired per year
with hired_by_year AS (
    SELECT
        EXTRACT(YEAR FROM hire_date) AS hire_year,
        COUNT(DISTINCT id) AS hires_count
    FROM employee
    GROUP BY EXTRACT(YEAR FROM hire_date)
    ORDER BY hire_year
),
TerminatedEmployees_ids AS (    -- IDS OF Terminations
    SELECT DISTINCT e.id AS employee_id
    FROM employee e
    LEFT JOIN department_employee de ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
      AND NOT EXISTS (
          SELECT 1
          FROM department_employee de_active
          WHERE de_active.employee_id = e.id
            AND de_active.to_date = '9999-01-01'
      )
),
TerminatedEmployees_info_and_count AS (
    SELECT
        EXTRACT(YEAR FROM de.to_date) AS terminate_year,
        COUNT(DISTINCT e.id) AS terminated_count
    FROM employee e
    INNER JOIN department_employee de 
    ON e.id = de.employee_id
    AND de.to_date = (
        SELECT MAX(de_sub.to_date)   -- Take the latest date for termination
        FROM department_employee de_sub
        WHERE de_sub.employee_id = de.employee_id
    )
    WHERE e.id IN (SELECT employee_id FROM TerminatedEmployees_ids)
    GROUP BY EXTRACT(YEAR FROM de.to_date)
    ORDER BY terminate_year
)
-- Final selection: combine hired and terminated data by year
SELECT
    h.hire_year,
    h.hires_count,
    t.terminate_year,
    COALESCE(t.terminated_count, 0) AS terminated_count
FROM hired_by_year h
FULL OUTER JOIN TerminatedEmployees_info_and_count t
ON h.hire_year = t.terminate_year
ORDER BY t.terminate_year;



SHOW temp_tablespaces;


------------------------------------------------------------------------------------------------


-- 19. Predict Potential High-Churn Departments
-- Use historical churn data to identify departments with a consistently high churn rate.

WITH TerminatedEmployees AS (
    SELECT 
        de.department_id,
        EXTRACT(YEAR FROM de.to_date) AS year,
        COUNT(DISTINCT e.id) AS terminated_count
    FROM employee e
    INNER JOIN department_employee de 
        ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
    GROUP BY de.department_id, EXTRACT(YEAR FROM de.to_date)
),
ActiveEmployees AS (
    SELECT 
        de.department_id,
        EXTRACT(YEAR FROM de.from_date) AS year,
        COUNT(DISTINCT e.id) AS active_count
    FROM employee e
    INNER JOIN department_employee de 
        ON e.id = de.employee_id
    WHERE de.to_date = '9999-01-01'  -- Currently active employees
    GROUP BY de.department_id, EXTRACT(YEAR FROM de.from_date)
),
DepartmentChurnRates AS (
    SELECT
        t.department_id,
        t.year,
        t.terminated_count,
        COALESCE(a.active_count, 0) AS active_count,
        (t.terminated_count + COALESCE(a.active_count, 0)) AS total_employees,
        CASE 
            WHEN (t.terminated_count + COALESCE(a.active_count, 0)) > 0 THEN 
                (t.terminated_count::NUMERIC / (t.terminated_count + COALESCE(a.active_count, 0))) * 100
            ELSE 0
        END AS churn_rate
    FROM TerminatedEmployees t
    FULL JOIN ActiveEmployees a
        ON t.department_id = a.department_id AND t.year = a.year
),
HighChurnDepartments AS (
    SELECT
        department_id,
        AVG(churn_rate) AS avg_churn_rate,
        COUNT(*) AS years_analyzed
    FROM DepartmentChurnRates
    WHERE year BETWEEN 1994 AND 2000  -- Specify the period
    GROUP BY department_id
    HAVING AVG(churn_rate) > 20  -- Threshold for high churn
    ORDER BY avg_churn_rate DESC
)
SELECT * from HighChurnDepartments

-- weighted average gives the same result.
"""HighChurnDepartments AS (
    SELECT
        department_id,
        SUM(churn_rate * total_employees) / NULLIF(SUM(total_employees), 0) AS weighted_avg_churn_rate,
        COUNT(*) AS years_analyzed
    FROM DepartmentChurnRates
    WHERE year BETWEEN 1994 AND 2000  -- Specify the period
    GROUP BY department_id
    HAVING SUM(churn_rate * total_employees) / NULLIF(SUM(total_employees), 0) > 20  -- Threshold for high churn
    ORDER BY weighted_avg_churn_rate DESC
)"""
SELECT 
    h.department_id,
    d.name AS department_name,  -- Assuming a 'departments' table for names
    h.avg_churn_rate,
    h.years_analyzed,
    '1994-2000' AS period  
FROM HighChurnDepartments h
JOIN departments d ON h.department_id = d.id
ORDER BY h.avg_churn_rate DESC;



---------------------------------------------------------------------------

-- 20. Evaluate Retention Strategies
-- Write a query to analyze if certain departments with a retention strategy 
-- (e.g., salary increases or promotions) have seen reduced churn.


-- 265332 COUNT OF SalaryChanges,Promotions

WITH TerminatedEmployees AS (
    SELECT 
        de.department_id,
        EXTRACT(YEAR FROM de.to_date) AS year,
        COUNT(DISTINCT e.id) AS terminated_count
    FROM employee e
    INNER JOIN department_employee de 
        ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
    GROUP BY de.department_id, EXTRACT(YEAR FROM de.to_date)
),
ActiveEmployees AS (
    SELECT 
        de.department_id,
        EXTRACT(YEAR FROM de.from_date) AS year,
        COUNT(DISTINCT e.id) AS active_count
    FROM employee e
    INNER JOIN department_employee de 
        ON e.id = de.employee_id
    WHERE de.to_date = '9999-01-01'  -- Currently active employees
    GROUP BY de.department_id, EXTRACT(YEAR FROM de.from_date)
),
DepartmentChurnRates AS (
    SELECT
        t.department_id,
        t.year,
        t.terminated_count,
        COALESCE(a.active_count, 0) AS active_count,
        (t.terminated_count + COALESCE(a.active_count, 0)) AS total_employees,
        CASE 
            WHEN (t.terminated_count + COALESCE(a.active_count, 0)) > 0 THEN 
                (t.terminated_count::NUMERIC / (t.terminated_count + COALESCE(a.active_count, 0))) * 100
            ELSE 0
        END AS churn_rate
    FROM TerminatedEmployees t
    FULL JOIN ActiveEmployees a
        ON t.department_id = a.department_id AND t.year = a.year
),
RetentionStrategies AS (
    SELECT 
        de.department_id,
        EXTRACT(YEAR FROM s.from_date) AS strategy_year -- Year when strategy started
    FROM department_employee de
    LEFT JOIN salary s ON de.employee_id = s.employee_id
    WHERE s.amount IS NOT NULL 
    GROUP BY de.department_id,strategy_year
),
ChurnBeforeAndAfter AS (
    SELECT
        dcr.department_id,
        rs.strategy_year,
        CASE 
            WHEN dcr.year < rs.strategy_year THEN 'Before Strategy'
            WHEN dcr.year >= rs.strategy_year THEN 'After Strategy'
            ELSE 'No Strategy'
        END AS strategy_period,
        AVG(dcr.churn_rate) AS avg_churn_rate
    FROM DepartmentChurnRates dcr
    LEFT JOIN RetentionStrategies rs ON dcr.department_id = rs.department_id
    GROUP BY dcr.department_id, rs.strategy_year, strategy_period
)
SELECT 
    department_id,
    strategy_period,
    AVG(avg_churn_rate) AS overall_avg_churn_rate,
    COUNT(*) AS years_analyzed
FROM ChurnBeforeAndAfter
GROUP BY department_id, strategy_period
ORDER BY department_id, strategy_period

select * from RetentionStrategies



