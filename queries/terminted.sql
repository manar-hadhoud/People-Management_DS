-- data discovery queries

-- number_terminatedemployees 91479
-- employees who are no longer active
SELECT  e.id, e.first_name, e.last_name, e.gender, 
       de.department_id, e.hire_date, de.from_date, de.to_date
FROM employee e
INNER JOIN department_employee de ON e.id = de.employee_id
WHERE de.to_date < CURRENT_DATE 

-------


SELECT COUNT(employee_id) FROM department_employee --331603 means employee can be in more than one department
SELECT COUNT(DISTINCT id) FROM employee --300024 no duplicates


-------


SELECT DISTINCT title
FROM title          -- 7 titles

SELECT COUNT(*)
FROM title      -- ONE employee can have more than one title


---------------------------------------------------------------------

-- 31579 have more than one apperance 
WITH DuplicateEmployees AS (
    SELECT de.employee_id
    FROM department_employee de
    GROUP BY de.employee_id
    HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM DuplicateEmployees

SELECT DISTINCT de.employee_id, de.from_date, de.to_date
FROM department_employee de
WHERE de.employee_id IN (SELECT employee_id FROM DuplicateEmployees)
ORDER BY de.employee_id, de.from_date

---------------------------------------------------------------------


-- 1- Identify Terminated Employees 59900
-- Write a query to list all employees who are no longer active

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


----------------------------------------------------------------------

-- 2- Retrieve All Employee Details Who Left in a Specific Year
-- Query to filter employees based on the year of their termination.

-- SELECT COUNT(e.id)

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
      AND EXTRACT(YEAR FROM de.to_date) = 1999
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

-- results:
-- year = 2002 --> 4011
-- year = 2001 --> 7333
-- year = 2000 --> 7869
-- year = 1999 --> 7381

-------------------------------------------------------------------------

-- 3.​Calculate the Total Number of Employees Who Left

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

-------------------------------------------------------------------------

-- churn rates:

-- 4- ​Find the Monthly Churn Rate

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
    ROUND((mc.employees_left * 100.0 / te.total_employees_by_month), 2) AS churn_rate_percentage,
    ROUND((mc.employees_left * 100.0 / (SELECT COUNT(*) FROM employee)), 2) AS churn_rate_total
FROM MonthlyChurn mc
JOIN TotalEmployees te
  ON mc.month = te.month
ORDER BY mc.month;

--------------------------------

-- 5. List Departments mWith the Most Employee Churn DONE
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


--------------------------------

-- 9. Compare Department Churn Rates 

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

----------------------------


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

------------------------------


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

------------------------------


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


---------------------------------------------------------


-- 8. Retrieve Employees With High Churn in a Specific Job Title   
-- number of employees leaving the organization from that specific job title
-- EXAMPLE COUNT OF Senior Engineer: 11811 & NO DUPLICATES



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
    (COUNT(terminated_employees.employee_id) * 100.0 / (SELECT total_count FROM total_employees)) AS churn_rate_job,
    (COUNT(terminated_employees.employee_id) * 100.0 / (SELECT COUNT(*) FROM employee)) AS churn_rate
FROM terminated_employees;

------------------------------------------------------------------------


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


