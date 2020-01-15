SELECT
	id,
	scafmol
INTO
	mols_scaf
FROM
	(SELECT id, mol_from_smiles(regexp_replace(scafsmi,E'\\\\s+.*$','')::cstring) AS scafmol
	FROM scaffold) t
WHERE
	scafmol IS NOT NULL
	;
