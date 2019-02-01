UPDATE public.scaffold s
SET prank = x.pr
FROM (
	SELECT id, rank() OVER (ORDER BY pscore DESC) AS pr
	FROM public.scaffold s2
	WHERE pscore IS NOT NULL
	) AS x
WHERE s.id = x.id
AND s.pscore IS NOT NULL
	;
