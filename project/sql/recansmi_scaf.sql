--
-- This  function is needed because the scaffold table is initially populated
-- using JChem canonicalization, which must be reindexed using OpenBabel/OpenChord
-- for the database to support lookup by scaffold structure (smiles).
-- This might be accomplished via single line of SQL:
--   UPDATE public.scaffold SET scafsmi=openbabel.cansmiles(scafsmi);
-- however in practice this fails, as an atomic transaction, due to any error
-- due to canonicalization collision of the scafsmi unique key.  Hence a separate
-- transaction for each row is required, best done via pl/pgsql.
--
-- Jeremy Yang
-- 10 Dec 2012
--
CREATE OR REPLACE FUNCTION recansmi_scaf(schema VARCHAR)
RETURNS integer AS
$$
DECLARE 
  scafid INTEGER := 1;
  n_mod INTEGER := 0;
  scafid_max INTEGER ;
BEGIN
EXECUTE 'SELECT MAX(id) FROM '||schema||'.scaffold' INTO scafid_max ;
LOOP
  EXIT WHEN scafid > scafid_max ;
  BEGIN
    EXECUTE 'UPDATE '||schema||'.scaffold SET scafsmi=openbabel.cansmiles(scafsmi) WHERE scaffold.id='||scafid ;
    n_mod := n_mod + 1;
  EXCEPTION WHEN unique_violation  THEN
    RAISE NOTICE 'UPDATE failed; unique violation; id = '||scafid ;
  END;
  scafid := scafid + 1;
END LOOP;
RETURN n_mod ;
END;
--
$$ LANGUAGE plpgsql;
--
