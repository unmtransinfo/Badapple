SELECT
	id,
	pscore,
	rank() OVER (ORDER BY pscore DESC)
FROM
	public.scaffold
WHERE
	id < 100
ORDER BY id
	;
--
