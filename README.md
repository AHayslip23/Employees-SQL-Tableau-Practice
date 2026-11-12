# Employees SQL Tableau Practice

A data pipeline project: a messy employee dataset is loaded into PostgreSQL, cleaned with SQL, exported to a clean CSV, and visualized in a Tableau dashboard.

## Repository Contents

| File | Description |
|---|---|
| `Messy_Employee_dataset.csv` | Raw dataset (1,020 employees) |
| `create_table_employee_staging.sql` | Creates the `employees_staging` table, with every column loaded as text |
| `employee_cleaning_script.sql` | PostgreSQL cleaning and feature engineering script |
| `cleaned_employee_data_set.csv` | Cleaned dataset exported from PostgreSQL (996 employees) |
| `Employee Dashboard.twbx` | Tableau packaged workbook with the employee dashboard |
| `boxplot2.png` | Exported boxplot image |

## Commit History

### `445646a`: Initial commit (2026-09-02)
- Created the repository with a `.gitattributes` file.

### `1192c70`: Commit #1, data cleaning in PostgreSQL (2026-09-02)
- **Loaded the data:** imported `Messy_Employee_dataset.csv` into PostgreSQL, using `create_table_employee_staging.sql` to create a staging table.
- **Added `employee_cleaning_script.sql`, which:**
  - converts `age` to integer and `salary` to float, after measuring and deleting rows where salary was `N/A`
  - splits `department_region` into separate `department` and `state_name` columns
  - drops PII columns (employee ID, first and last name, email and phone)
  - converts `remote_work` to boolean and `join_date` to a date, treating `N/A` and blanks as null
  - adds `year` and `month_year` columns from the join date
  - adds a PL/pgSQL function `get_region_by_state` that groups states into regions (West, Central, East, South, with Other as a fallback)
  - adds `income_level` and `age_group` categories
- **Exported the result** as `cleaned_employee_data_set.csv`.

### `e08c24f`: Commit #2, first draft of the Tableau dashboard (2026-09-03)
- **Added `Employee Dashboard.twbx` with these worksheets:**
  - Bins of Salaries (histogram)
  - Boxplot by Income Level and Salary
  - Boxplot of Salaries by Department
  - Performance Review Scores by Year
  - an unnamed draft sheet
  - an initial dashboard
- **Added `boxplot2.png`.**

### `82412a8`: Commit #3, updated visualizations and finished the dashboard (2026-09-04)
- **Removed the draft sheet and added three new worksheets:**
  - Count of Employees by Age Group
  - Count of Employees Signed Up for Remote Work
  - Hiring Trends by Region
- **Combined the visuals** into a single finished dashboard.

## Tools
PostgreSQL, Tableau, CSV
