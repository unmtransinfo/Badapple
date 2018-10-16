--
SELECT
	count(*) AS "total_samples_tested",
	count(DISTINCT sid) AS "total_substances_tested",
	count(DISTINCT aid) AS "total_assays_tested"
FROM
	activity
	;
--
SELECT
	count(*) AS "total_samples_active",
	count(DISTINCT sid) AS "total_substances_active",
	count(DISTINCT aid) AS "total_assays_active"
FROM
	activity
WHERE
	outcome=2
	;
--
