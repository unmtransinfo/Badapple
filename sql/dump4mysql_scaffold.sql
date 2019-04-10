--
SELECT
	id || E'\t' ||
	scafsmi || E'\t' ||
	scaftree || E'\t' ||
	ncpd_total || E'\t' ||
	ncpd_tested || E'\t' ||
	ncpd_active || E'\t' ||
	nsub_total || E'\t' ||
	nsub_tested || E'\t' ||
	nsub_active || E'\t' ||
	nass_tested || E'\t' ||
	nass_active || E'\t' ||
	nsam_tested || E'\t' ||
	nsam_active || E'\t' ||
	in_drug::INTEGER
FROM
	public.scaffold
	;
--
