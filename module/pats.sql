SELECT 
	pat, 
	per, 
	x1100pat.namechr, 
	CASE sex
		WHEN 'M' THEN 'männlich'
		WHEN 'W' THEN 'weiblich'
		ELSE sex
	END sex, 
	CASE inflock
		WHEN 0 Then '0-keine Sperre'
		WHEN 1 Then '1-Pfortenauskunft'
		WHEN 2 Then '2-totale Sperre'
	END AS inflock,
	TRUNC(SYSDATE) - TRUNC(admd) + 1 AS kranktage,
	(SELECT LISTAGG((TRUNC(SYSDATE) - TRUNC(docd)), ' | ') WITHIN GROUP (ORDER BY docd) FROM n2160fka WHERE n2160fka.can = x1102sta.can AND stat = 'A' AND attr = 146 GROUP BY pat) AS postoperativ_tage,
	x1100pat.admd, 
	x1100pat.typ, 
	TRUNC(birthd) AS birthd, 
	wds, 
	dep
FROM x1100pat
	JOIN x1000per USING (per)
	LEFT JOIN x1102sta USING (pat)
WHERE 
	SYSDATE BETWEEN admd AND disd
	AND admerrord is null
	AND reservmk = 0
	AND typ='S'     --Stationäre
	AND cha<>'BGL'  --Begleitpersonen
	AND wds<>'TEST' --Teststation
	AND wds LIKE :wdsFilter
	AND pat LIKE :patFilter
	AND x1100pat.man=:Mandant --Nur Mandant 1
	AND SYSDATE BETWEEN x1102sta.datf AND x1102sta.datt 
