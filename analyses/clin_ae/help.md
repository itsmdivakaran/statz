# Adverse Events Table

Counts subjects with each adverse event by treatment arm from event-level data (one row per event, as in a CDISC ADAE dataset).

**Assumptions**
- Each subject is counted once per event term, however often it occurred.
- Enter the number of subjects in each arm ('Subjects per arm'); otherwise only subjects with an event are counted and percentages are too high.
- Severity uses each subject's worst grade.

**Interpreting the output**
- Rows are grouped by system organ class and ordered by frequency.
- *Risk differences* versus the first arm (in percentage points) are descriptive; many events are compared, so expect some intervals to exclude 0 by chance.
- The heatmap highlights events that are more common on treatment.

**References**
- ICH E3: Structure and content of clinical study reports (1995).
- CDISC (2016). *ADaM structure for occurrence data (OCCDS)* v1.0.
