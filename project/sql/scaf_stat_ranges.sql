--
SELECT
	min(ncpd_total) AS "min_cTotal",
	max(ncpd_total) AS "max_cTotal"
FROM
	public.scaffold ;
SELECT
	min(ncpd_tested) AS "min_cTested",
	median(ncpd_tested) AS "med_cTested",
	max(ncpd_tested) AS "max_cTested",
	min(ncpd_active) AS "min_cActive",
	median(ncpd_active) AS "med_cActive",
	max(ncpd_active) AS "max_cActive"
FROM
	public.scaffold ;
--
SELECT
	min(nsub_total) AS "min_sTotal",
	max(nsub_total) AS "max_sTotal"
FROM
	public.scaffold ;
SELECT
	min(nsub_tested) AS "min_sTested",
	median(nsub_tested) AS "med_sTested",
	max(nsub_tested) AS "max_sTested",
	min(nsub_active) AS "min_sActive",
	median(nsub_active) AS "med_sActive",
	max(nsub_active) AS "max_sActive"
FROM
	public.scaffold ;
--
SELECT
	min(nass_tested) AS "min_aTested",
	median(nass_tested) AS "med_aTested",
	max(nass_tested) AS "max_aTested",
	min(nass_active) AS "min_aActive",
	median(nass_active) AS "med_aActive",
	max(nass_active) AS "max_aActive"
FROM
	public.scaffold ;
--
SELECT
	min(nsam_tested) AS "min_wTested",
	median(nsam_tested) AS "med_wTested",
	max(nsam_tested) AS "max_wTested",
	min(nsam_active) AS "min_wActive",
	median(nsam_active) AS "med_wActive",
	max(nsam_active) AS "max_wActive"
FROM
	public.scaffold ;
--
