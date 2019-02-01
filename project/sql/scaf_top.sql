SELECT
	id,
	scafsmi,
	pscore,
	prank,
	in_drug
FROM
	scaffold
WHERE
	pscore IS NOT NULL
ORDER BY pscore DESC
LIMIT 10
	;
--
