SELECT
	db_description || E'\t' ||
	'CURRENT_TIMESTAMP' || E'\t' ||
	median_ncpd_tested || E'\t' ||
	median_nsub_tested || E'\t' ||
	median_nass_tested || E'\t' ||
	median_nsam_tested
FROM
	public.metadata
	;
--
