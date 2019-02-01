-- Find scaf counts including non-null and non-zero:
SELECT count(*) AS "all_scaffolds" FROM public.scaffold ;
SELECT count(*) AS "null_scaffolds" FROM public.scaffold WHERE pscore IS NULL ;
SELECT count(*) AS "nonnull_scaffolds" FROM public.scaffold WHERE pscore IS NOT NULL ;
SELECT count(*) AS "zero_scaffolds" FROM public.scaffold WHERE pscore = 0 ;
SELECT count(*) AS "nonzero_scaffolds" FROM public.scaffold WHERE pscore > 0 ;
--
