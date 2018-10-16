-----------------------------------------------------------------------------
-- code from https://wiki.postgresql.org/wiki/Aggregate_Median
-- Postgresql 8.4+
-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _final_median(anyarray)
	RETURNS float8 AS $$ 
  WITH q AS
  (
     SELECT val
     FROM unnest($1) val
     WHERE VAL IS NOT NULL
     ORDER BY 1
  ),
  cnt AS
  (
    SELECT COUNT(*) AS c FROM q
  )
  SELECT AVG(val)::float8
  FROM 
  (
    SELECT val FROM q
    LIMIT  2 - MOD((SELECT c FROM cnt), 2)
    OFFSET GREATEST(CEIL((SELECT c FROM cnt) / 2.0) - 1,0)  
  ) q2;
$$ LANGUAGE SQL IMMUTABLE;
-- 
CREATE AGGREGATE median(anyelement) (
  SFUNC=array_append,
  STYPE=anyarray,
  FINALFUNC=_final_median,
  INITCOND='{}'
);
-----------------------------------------------------------------------------
-- code from postgresonline.com
-----------------------------------------------------------------------------
-- CREATE OR REPLACE FUNCTION array_median(numeric[])
--   RETURNS numeric AS
-- $$
--     SELECT
--       CASE
--         WHEN array_upper($1,1)=0 THEN null
--         ELSE asorted[ceiling(array_upper(asorted,1)/2.0)]
--       END
--     FROM (SELECT
--             ARRAY(SELECT ($1)[n]
--                   FROM generate_series(1, array_upper($1, 1)) AS n
--                   WHERE ($1)[n] IS NOT NULL
--                   ORDER BY ($1)[n]
--                  ) As asorted
--           ) As foo;
-- $$
--   LANGUAGE 'sql' IMMUTABLE;
-- 
-----------------------------------------------------------------------------
-- Postgresql 8.2+ syntax:
-- CREATE AGGREGATE median(numeric) (
--   SFUNC=array_append,
--   STYPE=numeric[],
--   FINALFUNC=array_median
-- );
-----------------------------------------------------------------------------
-- Postgresql 8.1 syntax:
-- CREATE AGGREGATE median (
--   BASETYPE=numeric,
--   SFUNC=array_append,
--   STYPE=numeric[],
--   INITCOND='{}',
--   FINALFUNC=array_median
-- );
-- 
-----------------------------------------------------------------------------
-- test:
-- SELECT m, median(n) As themedian, avg(n) as theavg
-- FROM generate_series(1, 58, 3) n, generate_series(1,5) m
-- WHERE n > m*2
-- GROUP BY m
-- ORDER BY m;
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- test:
-- select median(ncpd_tested) from scaffolds;
-- select median(nass_tested) from scaffolds;
-- select median(nsam_tested) from scaffolds;
-----------------------------------------------------------------------------

