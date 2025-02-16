-- number_terminatedemployees 91479
-- employees who are no longer active
SELECT  e.id, e.first_name, e.last_name, e.gender, 
       de.department_id, e.hire_date, de.from_date, de.to_date
FROM employee e
INNER JOIN department_employee de ON e.id = de.employee_id
WHERE de.to_date < CURRENT_DATE 

-- 31579 have more than one apperance 
WITH DuplicateEmployees AS (
    SELECT de.employee_id
    FROM department_employee de
    GROUP BY de.employee_id
    HAVING COUNT(*) > 1
)

SELECT de.employee_id, de.from_date, de.to_date
FROM department_employee de
WHERE de.employee_id IN (SELECT employee_id FROM DuplicateEmployees)
ORDER BY de.employee_id, de.from_date

-- handle special cases 66271
-----------------------------------------------------
 
-- 1. Identify Terminated Employees
WITH TerminatedEmployees AS (
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
)
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name,
    e.last_name,
    e.gender,
    e.hire_date,
    de.department_id, 
    de.from_date, 
    de.to_date
FROM employee e
INNER JOIN department_employee de 
    ON e.id = de.employee_id
    AND de.to_date = (
        SELECT MAX(de_sub.to_date)   -- TAKE THE LATEST DATE
        FROM department_employee de_sub
        WHERE de_sub.employee_id = de.employee_id
    )
WHERE e.id IN (SELECT employee_id FROM TerminatedEmployees)
ORDER BY e.id;

----------------------------------------------------------------------------------------------------


-- terminated in 2002 = 5877 ,
-- 2. All Employee Details Who Left in a Specific Year
-- SELECT COUNT(e.id)
SELECT DISTINCT 
    e.id, 
    e.first_name, 
    e.last_name, 
    e.gender, 
    de.department_id, 
    e.hire_date , 
    de.from_date, 
    de.to_date
FROM employee e
INNER JOIN department_employee de ON e.id = de.employee_id
WHERE EXTRACT(YEAR FROM de.to_date) = 2002;

-- optimization 4011 rows returned
WITH TerminatedEmployees AS (
    SELECT e.id AS employee_id
    FROM employee e
    LEFT JOIN department_employee de ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
      AND NOT EXISTS (
          SELECT 1
          FROM department_employee de_active
          WHERE de_active.employee_id = e.id
            AND de_active.to_date = '9999-01-01'
      )
      AND EXTRACT(YEAR FROM de.to_date) = 2002
)
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name,
    e.last_name,
    e.gender,
    e.hire_date,
    de.department_id, 
    de.from_date, 
    de.to_date
FROM employee e
INNER JOIN department_employee de 
    ON e.id = de.employee_id
    AND de.to_date = (
        SELECT MAX(de_sub.to_date)   -- TAKE THE LATEST DATE
        FROM department_employee de_sub
        WHERE de_sub.employee_id = de.employee_id
    )
WHERE e.id IN (SELECT employee_id FROM TerminatedEmployees)
ORDER BY e.id;


----------------------------------------------------------------------------------------------------
--terminated without duplicates 85108 one employee terminated from more than one department
SELECT COUNT(DISTINCT e.id)
FROM employee e
INNER JOIN department_employee de ON e.id = de.employee_id
WHERE de.to_date < CURRENT_DATE

-- right logic 
-- 59900 considering the special case  ver slowwwww
WITH ActiveEmployees AS (
    SELECT DISTINCT de.employee_id
    FROM department_employee de
    WHERE de.to_date = '9999-01-01'
),
TerminatedEmployees AS (
    SELECT e.id AS employee_id
    FROM employee e
    INNER JOIN department_employee de ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
    AND e.id NOT IN (SELECT employee_id FROM ActiveEmployees)
)
-- 3.​Calculate the Total Number of Employees Who Left
SELECT COUNT(employee_id) AS terminated_employees
FROM TerminatedEmployees;

-- OPTIMIZATION
SELECT COUNT(DISTINCT e.id) AS terminated_employees
FROM employee e
INNER JOIN department_employee de ON e.id = de.employee_id
WHERE de.to_date < CURRENT_DATE
AND NOT EXISTS (
    SELECT 1
    FROM department_employee de_active
    WHERE de_active.employee_id = e.id
    AND de_active.to_date = '9999-01-01'
);
---------------------------------------------------------------------------


----------------------------------------------------------------------

-- 4. calc the num of employees left each month 


-- calc the num of employees left each month 
-- divide it by the total number of employees(300024). wrong
-- right approach to calculate monthly churn rate

SELECT COUNT(employee_id) FROM department_employee --331603 means employee can be in more than one department
SELECT COUNT(DISTINCT id) FROM employee --300024 no duplicates


-- to ask if it is right to take only the entered peple in each month for total count.
WITH TerminatedEmployees AS (
    SELECT DISTINCT e.id AS employee_id, MAX(de.to_date) AS latest_to_date
    FROM employee e
    LEFT JOIN department_employee de ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
      AND NOT EXISTS (
          SELECT 1
          FROM department_employee de_active
          WHERE de_active.employee_id = e.id
            AND de_active.to_date = '9999-01-01'
      )
    GROUP BY e.id
),
MonthlyChurn AS (
    SELECT 
        EXTRACT(MONTH FROM te.latest_to_date) AS month,
        COUNT(DISTINCT te.employee_id) AS employees_left
    FROM TerminatedEmployees te
    GROUP BY EXTRACT(MONTH FROM te.latest_to_date)
),
TotalEmployees AS (
    SELECT 
        EXTRACT(MONTH FROM e.hire_date) AS month,
        COUNT(DISTINCT e.id) AS total_employees_by_month
    FROM employee e
    GROUP BY EXTRACT(MONTH FROM e.hire_date)
)
SELECT 
    mc.month,
    mc.employees_left,
    te.total_employees_by_month,
    ROUND((mc.employees_left * 100.0 / te.total_employees_by_month), 2) AS churn_rate_percentage
    ROUND((mc.employees_left * 100.0 / (SELECT COUNT(*) FROM employee)), 2) AS churn_rate_total
FROM MonthlyChurn mc
JOIN TotalEmployees te
  ON mc.month = te.month
ORDER BY mc.month;



--------------------------------------------------------------------------------------------------

-- 5. List Departments With the Most Employee Churn DONE
-- 
SELECT
    d.dept_name,
    de.department_id,
    COUNT(DISTINCT de.employee_id) AS employees_left
FROM department_employee de
JOIN department d
    ON de.department_id = d.id
WHERE EXTRACT(YEAR FROM de.to_date) <> 9999 -- Only count employees who have left
GROUP BY de.department_id, d.dept_name
ORDER BY employees_left DESC;

-- any department with no employees left to be included but we don't have this case here 
SELECT
    d.dept_name,
    de.department_id,
    COUNT(DISTINCT de.employee_id) AS employees_left
FROM department d
LEFT JOIN department_employee de
    ON de.department_id = d.id
    AND EXTRACT(YEAR FROM de.to_date) <> 9999 -- Employees who left
GROUP BY de.department_id, d.dept_name
ORDER BY employees_left DESC;



------------------------------------------------------------------------------------------------------

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



--------------------------------------------------------------------------------------------------

-- 7. ​Find Employees Who Worked Less Than a Year DONE
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


-- special cases handeled then 5535
-- COUNT 3206 rows returned
--------------------------------------------------------


-- 8. Retrieve Employees With High Churn in a Specific Job Title   (to ask)
-- number of employees leaving the organization from that specific job title
-- EXAMPLE COUNT OF Senior Engineer: 11811 & NO DUPLICATES


SELECT DISTINCT title
FROM title          -- 7 titles

SELECT COUNT(*)
FROM title      -- ONE employee can have more than one title


SELECT 
    t.employee_id,
    e.first_name,
    e.last_name
FROM title t
JOIN employee e 
    ON t.employee_id = e.id
WHERE t.to_date <> '9999-01-01' -- Only count employees who have left
    AND t.title = 'Senior Engineer'



WITH total_employees AS (
    SELECT COUNT(DISTINCT t.employee_id) AS total_count
    FROM title t
    JOIN employee e ON t.employee_id = e.id
    WHERE t.title = 'Senior Engineer'
),
terminated_employees AS (
    SELECT * 
    FROM title t
    JOIN employee e ON t.employee_id = e.id
    WHERE t.title = 'Senior Engineer'
    AND t.to_date <> '9999-01-01' -- Only count employees who have left
)
-- SELECT *
-- FROM terminated_employees

SELECT
    COUNT(terminated_employees.employee_id) AS total_terminated,
    (SELECT total_count FROM total_employees),
    (COUNT(terminated_employees.employee_id) * 100.0 / (SELECT total_count FROM total_employees)) AS churn_rate
FROM terminated_employees;



--------------------------------------------------------------------------------

-- 9. Compare Department Churn Rates DONE
-- subquery to calc churn rate for each department and rank them DESC.
SELECT
    department_id,
    dept_name,
    ROUND((churn_count * 1.0 / dep_employees), 4) AS churn_rate
FROM (
    SELECT
        d.dept_name,
        de.department_id,
        COUNT(CASE WHEN de.to_date <> '9999-01-01' THEN de.employee_id END) AS churn_count,
        COUNT(de.employee_id) AS dep_employees                           -- TO ASK BY TOTAL PEPLE OR BY ACTIVE ONES IN THE DEPARTMENT
    FROM department_employee de
    JOIN department d
    ON de.department_id = d.id
    GROUP BY de.department_id, d.dept_name
) AS department_churn 
ORDER BY churn_rate DESC


------------------------------------------------------------------------------------------------



-- 10. Identify the Average Tenure of Employees Who Left     DONE
-- Use a subquery to calc  average duration of employment for terminated employees.

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


-----------------------------------------------------------------------------------------------

-- 11. Analyze Churn by Gender
-- find the percentage of male and female employees who have left the organization.

WITH TerminatedEmployees AS (
    SELECT DISTINCT e.id AS employee_id
    FROM employee e
    INNER JOIN department_employee de ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
      AND NOT EXISTS (
          SELECT 1
          FROM department_employee de_active
          WHERE de_active.employee_id = e.id
            AND de_active.to_date = '9999-01-01'
      )
)

SELECT e.gender,COUNT(e.gender) AS terminated_count, 
    ROUND(COUNT(e.gender) * 100.0 / (SELECT COUNT(DISTINCT id) FROM employee), 2) AS percentage_totalEmp,
    ROUND(COUNT(e.gender) * 100.0 / (SELECT COUNT(*) FROM TerminatedEmployees), 2) AS percentage_ofterminated,
    ROUND(COUNT(e.gender) * 100.0 / (SELECT COUNT(DISTINCT id) FROM employee
                                    WHERE gender = e.gender), 2) AS GenderTotal_percentage
FROM employee e
JOIN TerminatedEmployees te
ON te.employee_id = e.id
GROUP BY e.gender

------------------------------------------------------------------------------------------

-- 12. Find the Most Common Termination Month
-- Group by to_date month and count the number of terminations to identify trends.

WITH TerminatedEmployees AS (
    SELECT DISTINCT e.id AS employee_id, MAX(de.to_date) AS latest_to_date
    FROM employee e
    LEFT JOIN department_employee de ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
      AND NOT EXISTS (
          SELECT 1
          FROM department_employee de_active
          WHERE de_active.employee_id = e.id
            AND de_active.to_date = '9999-01-01'
      )
    GROUP BY e.id
)

SELECT EXTRACT(MONTH FROM te.latest_to_date) AS month,
    COUNT(te.employee_id) AS terminated_count
FROM TerminatedEmployees te
GROUP BY EXTRACT(MONTH FROM te.latest_to_date)
ORDER BY terminated_count DESC


--------------------------------------------------------------------------------------------------

-- 13. Classify Employee Tenure DONE
-- Employee tenure refers to the length of time an employee has been working at a company
-- CASE statement to categorize employee tenure into 
-- "Short-Term" (<1 year), 
-- "Mid-Term" (1-3 years), 
-- "Long-Term" (>3 years).

--duplicates exist as employee can be in more than on department so we use id in employee table  (SOLVED)

SELECT 
    DISTINCT e.id,
    e.first_name,
    e.last_name,
    AGE(de.to_date, e.hire_date) AS tenure_duration,
    CASE
        WHEN AGE(de.to_date, e.hire_date) < INTERVAL '1 year' THEN 'Short-Term'
        WHEN AGE(de.to_date, e.hire_date) BETWEEN INTERVAL '1 year' AND INTERVAL '3 years' THEN 'Mid-Term'
        ELSE 'Long-Term'
    END AS tenure_category
FROM employee e
JOIN department_employee de
ON e.id = de.employee_id
WHERE de.to_date < CURRENT_DATE; 


--- optimization
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


----------------------------------------------------------------------------------------------------

-- 14. Label Employees Who Left Due to Churn 
-- Use a CASE statement to mark employees as "Churned" or "Retired" based on to_date and age.

SELECT 
    e.id,
    e.first_name,
    e.last_name,
    e.birth_date,
    de.to_date,
    CASE
        WHEN de.to_date < CURRENT_DATE AND EXTRACT(YEAR FROM AGE(de.to_date, e.birth_date)) >= 60 THEN 'Retired'  -- Assuming 60 as retirement age
        ELSE 'Churned' -- Assuming below 60 as churned
    END AS employee_status
FROM employee e
JOIN department_employee de
    ON e.id = de.employee_id
WHERE de.to_date < CURRENT_DATE;  -- Only consider employees who have left

--- optimization
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

-------------------------------------------------------------------------------------------------


-- Calculate Yearly Churn Trends
-- Use a CTE to group terminated employees by year and calculate yearly churn rates.



-- anomalies detected
SELECT 
    EXTRACT(YEAR FROM from_date) AS start_year,
    EXTRACT(YEAR FROM to_date) AS end_year,
    COUNT(employee_id) AS count
FROM department_employee
WHERE EXTRACT(YEAR FROM from_date) = EXTRACT(YEAR FROM to_date)
GROUP BY start_year, end_year
ORDER BY start_year;

-- terminated employees
WITH TerminatedEmployees AS (
    SELECT DISTINCT e.id AS employee_id, MAX(de.to_date) AS latest_to_date
    FROM employee e
    LEFT JOIN department_employee de ON e.id = de.employee_id
    WHERE de.to_date < CURRENT_DATE
      AND NOT EXISTS (
          SELECT 1
          FROM department_employee de_active
          WHERE de_active.employee_id = e.id
            AND de_active.to_date = '9999-01-01'
      )
    GROUP BY e.id
),
employee_churn_by_year AS (
    SELECT 
        EXTRACT(YEAR FROM te.latest_to_date) AS year,
        COUNT(DISTINCT te.employee_id) AS employees_left
    FROM TerminatedEmployees te
    GROUP BY year
),
TotalEmployees AS (
    SELECT 
        EXTRACT(YEAR FROM e.hire_date) AS year,
        COUNT(DISTINCT e.id) AS total_employees_by_year
    FROM employee e
    GROUP BY EXTRACT(YEAR FROM e.hire_date)
)
SELECT 
    yc.year,
    yc.employees_left,
    te.total_employees_by_year,
    ROUND((yc.employees_left * 100.0 / NULLIF(te.total_employees_by_year, 0)), 2) AS churn_rate_percentage
FROM employee_churn_by_year yc
LEFT JOIN TotalEmployees te
ON yc.year = te.year
ORDER BY yc.year;



---------------------

-- test but no space

with total_employees_by_year AS (
    SELECT 
        year,
        COUNT(DISTINCT employee_id) AS total_employees
    FROM (
        SELECT 
            EXTRACT(YEAR FROM GENERATE_SERIES(from_date, to_date, '1 year')) AS year,
            employee_id
        FROM department_employee
    ) active_years
    GROUP BY year
)
SELECT * 
FROM total_employees_by_year
ORDER BY year;

--------------------------------------------------------------------------------------------------

-- 16. Identify Top Departments by Churn Rate
-- Use a temporary table to store the total employees and churned employees for each department, 
-- then calculate churn rates.

-- Step 1: Create a Temporary Table to Store Total and Churned Employees

CREATE TEMPORARY TABLE temp_department_churn AS
SELECT 
    de.department_id,
    COUNT(DISTINCT e.id) AS total_employees,
    SUM(CASE WHEN de.to_date <> '9999-01-01' THEN 1 ELSE 0 END) AS churned_employees
FROM department_employee de
JOIN employee e 
    ON de.employee_id = e.id
GROUP BY de.department_id;


-- Step 2: Use the Temporary Table to Calculate Churn Rates

SELECT 
    d.dept_name,
    tdc.total_employees,
    tdc.churned_employees,
    ROUND((tdc.churned_employees * 100.0 / tdc.total_employees) , 2) AS churn_rate
FROM temp_department_churn tdc
JOIN department d
    ON tdc.department_id = d.id
ORDER BY churn_rate DESC;

------------------------------------------------------------------------------------------


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



