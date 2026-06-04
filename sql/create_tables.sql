-- sql/create_tables.sql

CREATE TABLE IF NOT EXISTS dim_student (
    student_id      SERIAL PRIMARY KEY,
    school          VARCHAR(5),
    sex             VARCHAR(1),
    age             INT,
    address         VARCHAR(1),        -- U = urban, R = rural
    famsize         VARCHAR(5),        -- GT3 = >3, LE3 = <=3
    pstatus         VARCHAR(1),        -- T = together, A = apart
    medu            INT,               -- mother education 0-4
    fedu            INT,               -- father education 0-4
    mjob            VARCHAR(20),
    fjob            VARCHAR(20),
    internet        VARCHAR(3),        -- yes / no
    famsup          VARCHAR(3),        -- family support yes / no
    paid            VARCHAR(3),        -- extra paid classes
    health          INT,               -- 1-5 scale
    course          VARCHAR(5)         -- math / por
);

CREATE TABLE IF NOT EXISTS fact_grades (
    grade_id        SERIAL PRIMARY KEY,
    student_id      INT  REFERENCES dim_student(student_id),
    course          VARCHAR(5),
    studytime       INT,               -- 1-4 weekly study hours scale
    failures        INT,               -- past failures
    absences        INT,
    g1              NUMERIC(5,2),      -- period 1 grade
    g2              NUMERIC(5,2),      -- period 2 grade
    g3              NUMERIC(5,2),      -- final grade
    gpa             NUMERIC(5,2),      -- avg of g1 g2 g3
    grade_trend     NUMERIC(5,2),      -- g3 - g1 (improvement or decline)
    passed          BOOLEAN,           -- g3 >= 10
    at_risk         BOOLEAN,           -- computed risk flag
    risk_score      NUMERIC(5,2)       -- 0-100 composite score
);