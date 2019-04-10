SELECT
	'INSERT INTO public.metadata' ||
	' (db_description, db_date_built, median_ncpd_tested, median_nsub_tested, median_nass_tested, median_nsam_tested )' ||
	' VALUES (' ||
	E'\'' || db_description || E'\',' ||
	' CURRENT_TIMESTAMP,' ||
	median_ncpd_tested || ',' ||
	median_nsub_tested || ',' ||
	median_nass_tested || ',' ||
	median_nsam_tested || ')' ||
	' ;'
FROM
	public.metadata
	;
--
SELECT
	'INSERT INTO public.scaffold' ||
	' (id, scafsmi, scaftree, ncpd_total, ncpd_tested, ncpd_active, nsub_total, nsub_tested, nsub_active, nass_tested, nass_active, nsam_tested, nsam_active, in_drug )' ||
	' VALUES (' ||
	id || ',' ||
	E'\'' || scafsmi || E'\',' ||
	E'\'' || scaftree || E'\',' ||
	ncpd_total || ',' ||
	ncpd_tested || ',' ||
	ncpd_active || ',' ||
	nsub_total || ',' ||
	nsub_tested || ',' ||
	nsub_active || ',' ||
	nass_tested || ',' ||
	nass_active || ',' ||
	nsam_tested || ',' ||
	nsam_active || ',' ||
	in_drug::INTEGER || ')' ||
	' ;'
FROM
	public.scaffold
	;
--
SELECT
	'INSERT INTO public.scaf2scaf' ||
	' (parent_id, child_id )' ||
	' VALUES (' ||
	parent_id || ',' ||
	child_id || ')' ||
	' ;'
FROM
	public.scaf2scaf
	;
--
SELECT
	'INSERT INTO public.compound' ||
	' (cid, cansmi, isosmi, nsub_total, nsub_tested, nsub_active, nass_tested, nass_active, nsam_tested, nsam_active )' ||
	' VALUES (' ||
	cid || ',' ||
	E'\'' || cansmi || E'\',' ||
	E'\'' || isosmi || E'\',' ||
	nsub_total || ',' ||
	nsub_tested || ',' ||
	nsub_active || ',' ||
	nass_tested || ',' ||
	nass_active || ',' ||
	nsam_tested || ',' ||
	nsam_active || ')' ||
	' ;'
FROM
	public.compound
	;
--
SELECT
	'INSERT INTO public.sub2cpd' ||
	' (sid, cid )' ||
	' VALUES (' ||
	sid || ',' ||
	cid || ')' ||
	' ;'
FROM
	public.sub2cpd
	;
--
SELECT
	'INSERT INTO public.scaf2cpd' ||
	' (scafid, cid )' ||
	' VALUES (' ||
	scafid || ',' ||
	cid || ')' ||
	' ;'
FROM
	public.scaf2cpd
	;
--
