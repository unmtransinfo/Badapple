--
SELECT
	cid || E'\t' ||
	cansmi || E'\t' ||
	isosmi || E'\t' ||
	nsub_total || E'\t' ||
	nsub_tested || E'\t' ||
	nsub_active || E'\t' ||
	nass_tested || E'\t' ||
	nass_active || E'\t' ||
	nsam_tested || E'\t' ||
	nsam_active
FROM
	public.compound
	;
--
