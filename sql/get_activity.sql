SELECT
	COUNT(DISTINCT public.sub2cpd.cid)
FROM
	public.activity,
	public.sub2cpd
WHERE
	public.activity.aid = 333
	AND public.sub2cpd.cid = 6603080
	AND public.activity.sid = public.sub2cpd.sid
	AND public.activity.outcome = 2
	;
