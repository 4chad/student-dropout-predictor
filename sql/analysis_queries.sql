-- sql/analysis_queries.sql


-- 1. At-risk students with full profile
SELECT
    d.student_id,
    d.sex,
    d.age,
    d.address,
    d.internet,
    f.g1, f.g2, f.g3,
    f.failures,
    f.absences,
    f.risk_score,
    f.grade_trend
FROM fact_grades f
JOIN dim_student d USING (student_id)
WHERE f.at_risk = TRUE
ORDER BY f.risk_score DESC;


-- 2. CTE — cohort dropout risk by school + course
WITH cohort_stats AS (
    SELECT
        d.school,
        f.course,
        COUNT(*)                                AS total_students,
        SUM(f.at_risk::int)                     AS at_risk_count,
        ROUND(AVG(f.risk_score)::numeric, 2)    AS avg_risk_score,
        ROUND(AVG(f.g3)::numeric, 2)            AS avg_final_grade,
        ROUND(AVG(f.absences)::numeric, 1)      AS avg_absences
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


-- 3. CTE — parental education vs student outcome
WITH parent_ed AS (
    SELECT
        d.medu,
        d.fedu,
        ROUND(AVG(f.gpa)::numeric, 2)           AS avg_gpa,
        ROUND(AVG(f.risk_score)::numeric, 2)    AS avg_risk,
        COUNT(*)                                AS students,
        ROUND(AVG(CASE WHEN f.passed THEN 1.0
                       ELSE 0.0 END) * 100, 1) AS pass_rate_pct
    FROM fact_grades f
    JOIN dim_student d USING (student_id)
    GROUP BY d.medu, d.fedu
)
SELECT * FROM parent_ed
ORDER BY avg_gpa DESC;


-- 4. Window function — rank students by risk score within school
SELECT
    d.school,
    d.student_id,
    f.risk_score,
    f.g3,
    f.failures,
    RANK() OVER (
        PARTITION BY d.school
        ORDER BY f.risk_score DESC
    )                                           AS risk_rank_in_school
FROM fact_grades f
JOIN dim_student d USING (student_id)
ORDER BY d.school, risk_rank_in_school;


-- 5. Window function — LAG to see grade progression
SELECT
    student_id,
    course,
    'G1'                                        AS period,
    g1                                          AS grade
FROM fact_grades
UNION ALL
SELECT student_id, course, 'G2', g2 FROM fact_grades
UNION ALL
SELECT student_id, course, 'G3', g3 FROM fact_grades
ORDER BY student_id, period;


-- 6. Impact of internet access on outcomes
SELECT
    d.internet,
    COUNT(*)                                    AS students,
    ROUND(AVG(f.g3)::numeric, 2)                AS avg_final_grade,
    ROUND(AVG(f.risk_score)::numeric, 2)        AS avg_risk_score,
    ROUND(AVG(f.absences)::numeric, 1)          AS avg_absences
FROM fact_grades f
JOIN dim_student d USING (student_id)
GROUP BY d.internet;


-- 7. CTE — study time effectiveness
WITH study_groups AS (
    SELECT
        f.studytime,
        COUNT(*)                                AS students,
        ROUND(AVG(f.gpa)::numeric, 2)           AS avg_gpa,
        ROUND(AVG(f.risk_score)::numeric, 2)    AS avg_risk,
        SUM(f.at_risk::int)                     AS at_risk_count
    FROM fact_grades f
    GROUP BY f.studytime
)
SELECT
    studytime,
    CASE studytime
        WHEN 1 THEN '<2 hrs/week'
        WHEN 2 THEN '2-5 hrs/week'
        WHEN 3 THEN '5-10 hrs/week'
        WHEN 4 THEN '>10 hrs/week'
    END                                         AS study_label,
    students,
    avg_gpa,
    avg_risk,
    at_risk_count
FROM study_groups
ORDER BY studytime;