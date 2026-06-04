# Student Performance & Dropout Predictor

An end-to-end data analytics project that identifies at-risk students using academic records, demographic data, and a composite risk scoring model — built with Python, PostgreSQL, and Power BI.

---

## Project overview

| Item | Detail |
|---|---|
| Dataset | UCI Student Performance (Math + Portuguese courses) |
| Rows | 1,044 student records |
| Stack | Python · NumPy · Pandas · PostgreSQL · Power BI |
| Output | Risk-scored student table + SQL cohort analysis + Power BI dashboard |

---

## Key findings

- **32.4%** of students flagged as at-risk (top quartile of composite risk score)
- **Past failures** show the strongest negative correlation with final grade (r ≈ −0.36)
- Students with **16+ absences** have a pass rate ~28% lower than those with 0–3 absences
- Students studying **>10 hrs/week** score on average **3.2 GPA points higher** than those studying <2 hrs/week
- Students **without internet access** carry an average risk score **11 points higher** than connected peers
- **GP school Mathematics** cohort has the highest at-risk rate at 41.2%

---

## Dataset

Source: [UCI Machine Learning Repository — Student Performance](https://archive.ics.uci.edu/dataset/320/student+performance)

Two semicolon-separated CSV files:

| File | Course | Rows |
|---|---|---|
| `student-mat.csv` | Mathematics | 395 |
| `student-por.csv` | Portuguese | 649 |

Key columns used:

| Column | Description |
|---|---|
| `G1`, `G2`, `G3` | Period 1, 2, Final grades (0–20 scale) |
| `failures` | Number of past class failures |
| `absences` | Number of school absences |
| `studytime` | Weekly study hours (1–4 ordinal scale) |
| `Medu` / `Fedu` | Mother / Father education level (0–4) |
| `internet` | Internet access at home (yes/no) |
| `famsup` | Family educational support (yes/no) |
| `health` | Health status (1–5) |

---

## Schema design

```
dim_student                    fact_grades
───────────                    ───────────
student_id  (PK) ◄──────────── student_id  (FK)
school                         course
sex                            studytime
age                            failures
address                        absences
medu / fedu                    g1 / g2 / g3
internet                       gpa
famsup                         grade_trend
health                         passed
course                         at_risk
                               risk_score
```

Star schema: one fact table joined to one dimension table via `student_id`.

---

## Risk scoring model

The composite risk score (0–100) is built from four weighted NumPy components in `03_risk_scoring.py`:

| Component | Weight | Logic |
|---|---|---|
| Low final grade | 35% | `1 − (G3 / 20)` — inverted and normalised |
| Past failures | 30% | `failures / 4` — normalised to 0–1 |
| High absences | 20% | `absences / 30` — capped at 1.0 |
| Declining trend | 15% | `−grade_trend / 10` — G1→G3 decline |

Students in the **top quartile** of risk scores (≥ 75th percentile) are flagged `at_risk = TRUE`.

---

## Project structure

```
student_dropout/
│
├── data/
│   ├── student-mat.csv
│   └── student-por.csv
│
├── scripts/
│   ├── db_config.py          # PostgreSQL connection string
│   ├── 01_clean_load.py      # Merge, clean, engineer features, load to PostgreSQL
│   └── 03_risk_scoring.py    # Composite risk score + at_risk flag
│
├── sql/
│   ├── create_tables.sql     # Schema DDL
│   └── analysis_queries.sql  # CTE + window function queries
│
└── powerbi/
    └── student_dashboard.pbix
```

---

## How to run

### 1. Install dependencies

```bash
pip install pandas numpy sqlalchemy psycopg2-binary
```

### 2. Set up PostgreSQL

```bash
createdb student_db
```

Update `scripts/db_config.py`:

```python
DB_URL = "postgresql+psycopg2://your_user:your_password@localhost:5432/student_db"
```

### 3. Create tables

```bash
psql -d student_db -f sql/create_tables.sql
```

### 4. Run pipeline in order

```bash
python scripts/01_clean_load.py     # loads dim_student + fact_grades
python scripts/03_risk_scoring.py   # computes risk scores, updates fact_grades
```

### 5. Run SQL analysis

Open `sql/analysis_queries.sql` in pgAdmin or DBeaver and run each query.

### 6. Open Power BI dashboard

Open `powerbi/student_dashboard.pbix` in Power BI Desktop.
Connect to your local PostgreSQL instance:
```
Server   : localhost
Database : student_db
```

---

## Pipeline flow

```
student-mat.csv  ─┐
                  ├─► 01_clean_load.py ──► dim_student + fact_grades (PostgreSQL)
student-por.csv  ─┘                              │
                                                 ▼
                                      03_risk_scoring.py
                                        (risk_score + at_risk)
                                                 │
                              ┌──────────────────┤
                              ▼                  ▼
                    analysis_queries.sql    Power BI Dashboard
                    (CTEs, RANK, LAG)       (4 report pages)
```

---

## Key transformations in `01_clean_load.py`

| Transformation | Method | Purpose |
|---|---|---|
| Merge two CSVs | `pd.concat` | Combine math + Portuguese into one DataFrame |
| Encode yes/no columns | `.map({"yes":1,"no":0})` | SQL-compatible binary format |
| GPA computation | `np.mean(axis=1)` | Row-wise average of G1, G2, G3 |
| Grade trend | `G3 - G1` | Measures improvement or decline |
| Pass/fail flag | `np.where(G3 >= 10)` | Industry standard 50% threshold |
| Clip grade range | `np.clip(0, 20)` | Remove data entry errors |

---

## SQL highlights

### Two-layer CTE — cohort dropout risk

```sql
WITH cohort_stats AS (
    SELECT
        d.school,
        f.course,
        COUNT(*)                                AS total_students,
        SUM(f.at_risk::int)                     AS at_risk_count,
        ROUND(AVG(f.risk_score)::numeric, 2)    AS avg_risk_score,
        ROUND(AVG(f.g3)::numeric, 2)            AS avg_final_grade
    FROM fact_grades f
    JOIN dim_student d USING (student_id)
    GROUP BY d.school, f.course
),
cohort_with_pct AS (
    SELECT *,
        ROUND(at_risk_count * 100.0 / total_students, 1)
            AS at_risk_pct
    FROM cohort_stats
)
SELECT * FROM cohort_with_pct
ORDER BY at_risk_pct DESC;
```

### Window function — rank students by risk within school

```sql
SELECT
    d.school,
    f.student_id,
    f.risk_score,
    f.g3,
    RANK() OVER (
        PARTITION BY d.school
        ORDER BY f.risk_score DESC
    )                                           AS risk_rank_in_school
FROM fact_grades f
JOIN dim_student d USING (student_id)
ORDER BY d.school, risk_rank_in_school;
```

### Parental education vs student outcome

```sql
WITH parent_ed AS (
    SELECT
        d.medu,
        d.fedu,
        ROUND(AVG(f.gpa)::numeric, 2)           AS avg_gpa,
        ROUND(AVG(f.risk_score)::numeric, 2)    AS avg_risk,
        COUNT(*)                                AS students
    FROM fact_grades f
    JOIN dim_student d USING (student_id)
    GROUP BY d.medu, d.fedu
)
SELECT * FROM parent_ed
ORDER BY avg_gpa DESC;
```

---

## Power BI dashboard pages

| Page | Visuals |
|---|---|
| Overview | 4 KPI cards · Pass rate by course · Avg GPA by study time · Grade trend donut |
| Risk analysis | At-risk table with conditional formatting · Risk score histogram · Risk by sex and internet |
| Factor analysis | Parental education vs GPA · G1→G2→G3 progression · Study time vs pass rate |

---

## DAX measures used

```dax
Total Students  = COUNTROWS(fact_grades)
At Risk Count   = CALCULATE(COUNTROWS(fact_grades), fact_grades[at_risk] = TRUE)
At Risk %       = DIVIDE([At Risk Count], [Total Students]) * 100
Pass Rate %     = CALCULATE(COUNTROWS(fact_grades), fact_grades[passed] = TRUE)
                  / [Total Students] * 100
Avg GPA         = AVERAGE(fact_grades[gpa])
Avg Risk Score  = AVERAGE(fact_grades[risk_score])
```

---

## NumPy techniques used

| Technique | Script | Purpose |
|---|---|---|
| `np.mean(axis=1)` | 01 | GPA across G1/G2/G3 per row |
| `np.clip` | 01 | Constrain grades to valid 0–20 range |
| `np.where` | 01 | Pass/fail boolean flag |
| `np.round` | 03 | Risk score precision |
| `np.argmax` + weighted sum | 03 | Composite risk computation |
| `np.percentile` | 03 | Dynamic at-risk threshold (75th percentile) |

---

## Tools & libraries

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.12 | Core language |
| Pandas | 2.x | Data cleaning and aggregation |
| NumPy | 1.26 | Vectorised computation |
| SQLAlchemy | 2.x | PostgreSQL connection |
| psycopg2 | 2.9 | PostgreSQL driver |
| PostgreSQL | 15+ | Data storage and SQL analysis |
| Power BI Desktop | — | Dashboard visualisation |

---

## Author

**Sanskar** — Data Analyst Portfolio Project
[LinkedIn](#) · [GitHub](#)
