#!/bin/bash
# Query for status and outs daily per tool per process .\m/
# KEVIN B MOCORRO
# 2018-04-20

PATH=$PATH:/c/xampp/mysql/bin
HOST=""
USER=""
DS_USER=""
DS_PASS=""
PASS=""
DS_DB=""
DB=""
#PROCESS="DAMAGE"
LOAD_START_DATE=2017-1-11
LOAD_END_DATE=2018-04-19
STARTDATE=$(date -I -d "$LOAD_START_DATE") || exit -1
ENDDATE=$(date -I -d "$LOAD_END_DATE") || exit -1

PROCESS_ARR=("<insert process name here>")


d="$STARTDATE"

while [ "$d" != "$ENDDATE" ]; do

	for PROCESS in "${PROCESS_ARR[@]}"
	do
	echo "Extracting " $PROCESS " " $d " data..."
mysql -h$HOST -u$USER -p$PASS $DB -N -e "SELECT '$d', '$PROCESS', A.eq_name, ROUND((A.P/24) * 100, 2), ROUND((A.SU/24) * 100, 2), ROUND((A.SD/24) * 100, 2), ROUND((A.D/24) * 100, 2), ROUND((A.E/24) * 100, 2), ROUND((A.SB/24) * 100, 2), B.outs FROM (SELECT pretty_table.eq_id, pretty_table.eq_name, COALESCE(P, 0) AS P, COALESCE(SU, 0) AS SU, COALESCE(SD, 0) AS SD, COALESCE(D, 0) AS D, COALESCE(E, 0) AS E, COALESCE(SB, 0) AS SB FROM (SELECT extended_table.eq_id, extended_table.eq_name, SUM(P) AS P, SUM(SU) AS SU, SUM(SD) AS SD, SUM(D) AS D, SUM(E) AS E, SUM(SB) AS SB FROM (SELECT base_table.*, CASE WHEN base_table.stat_id = 'P' THEN base_table.duration END AS P, CASE WHEN base_table.stat_id = 'SU' THEN base_table.duration END AS SU, CASE WHEN base_table.stat_id = 'SD' THEN base_table.duration END AS SD, CASE WHEN base_table.stat_id = 'D' THEN base_table.duration END AS D, CASE WHEN base_table.stat_id = 'E' THEN base_table.duration END AS E, CASE WHEN base_table.stat_id = 'SB' THEN base_table.duration END AS SB FROM (SELECT G.eq_id, G.eq_name, G.stat_id, SUM(ROUND(TIME_TO_SEC(TIMEDIFF(G.time_out, G.time_in)) / 3600, 2)) AS duration FROM (SELECT C.eq_id, C.eq_name, B.stat_id, IF(B.time_in <= CONCAT('$d', ' 06:30:00') && B.time_out >= CONCAT('$d', ' 06:30:00'), CONCAT('$d', ' 06:30:00'), IF(B.time_in <= CONCAT('$d', ' 06:30:00'), CONCAT('$d', ' 06:30:00'), IF(B.time_in >= CONCAT('$d' + INTERVAL 1 DAY, ' 06:30:00'), CONCAT('$d' + INTERVAL 1 DAY, ' 06:30:00'), B.time_in))) AS time_in, IF(B.time_in <= CONCAT('$d' + INTERVAL 1 DAY, ' 06:30:00') && B.time_out >= CONCAT('$d' + INTERVAL 1 DAY, ' 06:30:00'), CONCAT('$d' + INTERVAL 1 DAY, ' 06:30:00'), IF(B.time_out <= CONCAT('$d', ' 06:30:00'), CONCAT('$d', ' 06:30:00'), IF(B.time_out >= CONCAT('$d' + INTERVAL 1 DAY, ' 06:30:00'), CONCAT('$d' + INTERVAL 1 DAY, ' 06:30:00'), IF(B.time_out IS NULL && B.time_in < CONCAT('$d' + INTERVAL 1 DAY, ' 06:30:00'), CONVERT_TZ(NOW(), @@SESSION .TIME_ZONE, '+08:00'), B.time_out)))) AS time_out FROM (SELECT eq_id, proc_id FROM MES_EQ_PROCESS WHERE proc_id = '$PROCESS' GROUP BY eq_id) A JOIN MES_EQ_CSTAT_HEAD B ON A.eq_id = B.eq_id JOIN MES_EQ_INFO C ON A.eq_id = C.eq_id WHERE B.time_in >= CONCAT('$d' - INTERVAL 2 DAY, ' 00:00:00') AND A.proc_id = '$PROCESS') G GROUP BY G.eq_name , G.stat_id) base_table) extended_table GROUP BY extended_table.eq_name) pretty_table) A JOIN (SELECT A.eq_id, A.process_id, B.eq_name, A.outs FROM (SELECT eq_id, process_id, SUM(out_qty) AS outs FROM MES_OUT_DETAILS WHERE process_id = '$PROCESS' AND date_time >= CONCAT('$d', ' 06:30:00') && date_time <= CONCAT('$d' + INTERVAL 1 DAY, ' 06:29:59') GROUP BY eq_id) A JOIN (SELECT eq_id, eq_name FROM MES_EQ_INFO) B ON A.eq_id = B.eq_id GROUP BY eq_name) B ON A.eq_id = B.eq_id "  | sed 's/\t/,/g' > $PROCESS-DATA.csv

	IFS=,
	cat $PROCESS-DATA.csv | while read extracted_date process_name tool_name P SU SD DT E SB OUTS
	do
	echo "INSERT INTO deepmes_status_and_outs (extracted_date, process_name, tool_name, P, SU, SD, D, E, SB, OUTS) VALUES ('$extracted_date', '$process_name', '$tool_name', '$P', '$SU', '$SD', '$DT', '$E', '$SB', '$OUTS');"
	
	done < $PROCESS-DATA.csv | mysql -h$HOST -u$DS_USER -p$DS_PASS $DS_DB; 
	
	done
	echo "Saved to Database..."
	d=$(date -I -d "$d + 1 day")
done



