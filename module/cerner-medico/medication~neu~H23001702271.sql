SELECT 
	m2530mdc.mdc,
	m2530mdc.des,
	regexp_substr((SELECT LISTAGG(attval,'') WITHIN GROUP (ORDER BY attcol,attrow) wirkstoff FROM m2501mda WHERE m2501mda.att='MED_DESXL' AND m2501mda.mdc=m2530mdc.mdc AND attcol=0), '\[(.*)\]', 1, 1, 'i',1) AS wirkstoff,
	adm_info_table.attval AS ADM_INFO,
	add_ondemand_table.attval AS ADD_ONDEMAND,
	(SELECT LISTAGG(attval,'') WITHIN GROUP (ORDER BY attcol,attrow) DOS_COMMENT FROM m2504doa WHERE m2504doa.att='DOS_COMMENT' AND m2504doa.dos=m2531dos.dos) AS DOS_COMMENT,
	CASE adm_roa_table.attval
		WHEN 'T0029A4%OR' THEN 'oral'
		WHEN 'T002AF2%SUB' THEN 'subcutan'
		WHEN 'T0023CA%IVN' THEN 'i.v.'
		WHEN 'T00232E%BP' THEN 'pulmonal'
		WHEN 'T002AF0%RE' THEN 'rektal'
		WHEN 'T002AEC%MH' THEN 'Mundhöhle'
		WHEN 'T002AC3%TD' THEN 'transdermal'
		WHEN 'T000018%IK' THEN 'intrakorporal'
		WHEN 'GA00B71%EX' THEN 'topisch/extern'
		WHEN 'T002287%PA' THEN 'parenteral'
		WHEN 'V0001B1%INH' THEN 'inhalativ'
		ELSE adm_roa_table.attval
	END AS ADM_ROA,
	CASE 
		WHEN SYSDATE > m2531dos.datt THEN 'abgesetzt'
	ELSE
		CASE m2531dos.state
			WHEN 0 THEN 'aktiv'
			WHEN 1 THEN 'vorgeschlagen'
			WHEN 5 THEN 'pausiert'
			WHEN 6 THEN 'aktiv, nachts pausiert'
			WHEN 7 THEN 'prüfen (und pausiert)'
			ELSE 'unbekannt'
		END
	END AS Status,
	m2531dos.datf AS datf,
	m2531dos.datt AS datt,
	m2531dos.sertype,
	m2531dos.weekdays,
	m2531dos.periodicity,
	x8201psr.namechr as orderer,
	m2531dos.orderts AS orderts
FROM m2530mdc
	JOIN m2531dos ON m2530mdc.mdc = m2531dos.mdc
	LEFT JOIN m2504doa adm_roa_table ON adm_roa_table.dos=m2531dos.dos AND adm_roa_table.att='ADM_ROA' AND adm_roa_table.attcol=0 AND adm_roa_table.attrow=0
	LEFT JOIN m2504doa add_ondemand_table ON add_ondemand_table.dos=m2531dos.dos AND add_ondemand_table.att='ADD_ONDEMAND' AND add_ondemand_table.attcol=0 AND add_ondemand_table.attrow=0
	LEFT JOIN m2504doa adm_info_table ON adm_info_table.dos=m2531dos.dos AND adm_info_table.att='ADM_INFO' AND adm_info_table.attcol=0 AND adm_info_table.attrow=0
	JOIN x8201psr ON x8201psr.psr = m2531dos.orderer
WHERE
	per = :per
	AND pat = :pat
	AND SYSDATE BETWEEN (m2531dos.datf-5) AND m2531dos.datt
	AND NOT m2531dos.state = -5 --storniert
ORDER BY UPPER(des)