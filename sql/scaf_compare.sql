-- Find top scaf from dataset A in dataset B.
SELECT
	id,
	prank,
	pscore,
	scafsmi
FROM
	public.scaffold
WHERE
	scafsmi IN (
		SELECT scafsmi
		FROM badapple1.scaffold 
		WHERE prank = 1
	)
	;
--
