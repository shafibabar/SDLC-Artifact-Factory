---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says that opportunity scoring (Importance + max(Importance − Satisfaction, 0)) applies to desired outcomes within a job, not to whole jobs, and it does not present a ranking of the three whole jobs by opportunity score as its answer (computing the job-level numbers only to show why they should not be used is fine).
2. It writes at least two desired-outcome statements under a job in the form direction + metric + object + clarifier (for example "Minimize the time it takes to …" or "Minimize the likelihood that …").
3. It says that four owners are too few for the numeric score to be reliable (at most directional), and it ranks or recommends ranking outcomes by a qualitative compare-and-contrast of the options (for example sizing, how important, how badly served today), reserving numeric opportunity scores for a larger survey sample.
Fail if any of the three is missing.
