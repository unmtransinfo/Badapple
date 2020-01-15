SELECT
	cid, mol
INTO
	mols
FROM
	(SELECT cid, mol_from_smiles(regexp_replace(isosmi,E'\\\\s+.*$','')::cstring) AS mol
	FROM compound) t
WHERE
	mol IS NOT NULL
	;
