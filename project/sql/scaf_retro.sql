-- Find high score scafs from older dataset A which are in newer dataset B, and for which more data exists.
SELECT
	'"'||badapple_classic.scaffold.scafsmi||'"' AS "smiles",
	public.scaffold.id AS "id_new",
	public.scaffold.pscore AS "pscore_new",
        public.scaffold.nsub_tested AS "sTested_new",
        public.scaffold.nsub_active AS "sActive_new",
        public.scaffold.nass_tested AS "aTested_new",
        public.scaffold.nass_active AS "aActive_new",
        public.scaffold.nsam_tested AS "wTested_new",
        public.scaffold.nsam_active AS "wActive_new",
	badapple_classic.scaffold.id AS "id_old",
	badapple_classic.scaffold.pscore AS "pscore_old",
        badapple_classic.scaffold.nsub_tested AS "sTested_old",
        badapple_classic.scaffold.nsub_active AS "sActive_old",
        badapple_classic.scaffold.nass_tested AS "aTested_old",
        badapple_classic.scaffold.nass_active AS "aActive_old",
        badapple_classic.scaffold.nsam_tested AS "wTested_old",
        badapple_classic.scaffold.nsam_active AS "wActive_old",
        (public.scaffold.nsam_tested - badapple_classic.scaffold.nsam_tested) AS "wTested_diff"
FROM
	public.scaffold
JOIN
	badapple_classic.scaffold ON (badapple_classic.scaffold.scafsmi = public.scaffold.scafsmi)
WHERE
	badapple_classic.scaffold.pscore >= 300
ORDER BY "wTested_diff" DESC
	;
--
