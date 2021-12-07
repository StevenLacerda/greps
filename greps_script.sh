#!/bin/bash

# USAGE
# check both for options, but it will be something like greps -ncgs or 
# greps -a for everything, or just greps for everything


# TODO
# add a grep for chrony
# add a grep for average flush size
# add a grep for ERROR
# add a grep for timeout, timedout


mkdir Nibbler
grep_file="Nibbler/1-greps.out"
config_file="Nibbler/1-config.out"
solr_file="Nibbler/1-solr.out"
sperf_file="Nibbler/1-sperf-statuslogger.out"
diag_file="Nibbler/1-sperf-diag.out"
sixo="Nibbler/1-sixo.out"
warn="Nibbler/1-warnings.out"
error="Nibbler/1-errors.out"
threads="Nibbler/1-threads.out"
slow_queries="Nibbler/1-slow-queries.out"
gcs="Nibbler/1-gcs.out"
tombstone_file="Nibbler/1-tombstones.out"
histograms="Nibbler/1-histograms.out"
drops="Nibbler/1-drops.out"
queues="Nibbler/1-queues.out"
iostat="Nibbler/1-iostat"
hash_line="=========================================================================================================="



# $1 is heading line
# $2 is bash command
function echo_request() {
	if [ -z $2 ]
	then 
		file=$grep_file
	else
		file=$2
	fi
	echo >> $file
	echo $hash_line >> $file
	echo $1 >> $file
}


# runs nibbler if no -l option
function nibbler() {
	# get version info
	version=$(egrep -i ".*" $(find . -name version | head -1))
	major_version=$(echo $version | awk -F'.' '{print $NF}' | cut -c1-1)
	node_status="Nibbler/Node_Status.out"
	today=$(find . -name "system.log" -o -name "debug.*"| tail -1 $(head -1) | grep -oh "\d\d\d\d-\d\d-\d\d")
	java -jar ~/Downloads/~nibbler/Nibbler.jar ./
	cluster_config_summary="Cluster_Configuration_Summary.out"
	egrep -i ".*" $(find . -name version | head -1) >> $grep_file

	# echo "system.log start: " >> $grep_file
	for f in `find ./ -type file -name system.log -o -name debug.log`; 
		do 
			echo $f >> $grep_file
			grep -o "\d\d\d\d-\d\d-\d\d\ \d\d:\d\d" $f | head -1 >> $grep_file
			grep -o "\d\d\d\d-\d\d-\d\d\ \d\d:\d\d" $f | tail -1 >> $grep_file
			echo >> $grep_file
		done

	# echo_request "NODE STATUS"
	# cat $node_status >> $grep_file

	# config file section
	# echo "DISK CONFIGURATION" >> $config_file
	# egrep -Rh '======\ |^\s.*-' ./ --include=$cluster_config_summary | sed -e $'s/^====== /\\\n/g' >> $config_file

	# echo >> $config_file
	# echo "CONFIGURATION" >> $config_file 
	# egrep -Rh '===== \d|Number|Machine' ./ --include=$cluster_config_summary | sed -e $'s/^====== /\\\n/g' >> $config_file
}


function config() { 
	touch $config_file
	echo_request "YAML VALUES" $config_file

	for f in `find . -type file -name cassandra.yaml`;
	do
		echo $f | grep -o '[0-9].*[0-9]' >> $config_file
		egrep -ih "^memtable_|^#.*memtable_.*:|^concurrent_|^commitlog_segment|^commitlog_total|^#.*commitlog_total.*:|^compaction_|^incremental_backups|^tpc_cores|^disk_access_mode" $f >> $config_file
		echo >> $config_file
	done
}
# end config file section


function sixO() {
	touch $sixo
	echo "6.x Specific greps" > $sixo
	
	echo_request "TOO MANY PENDING REQUESTS" $sixo
	egrep -ciR 'Too many pending remote requests' ./ --include={system,debug}* >> $sixo

	echo_request "BACKPRESSURE REJECTION" $sixo
	egrep -R 'Backpressure rejection while receiving' ./ --include={system,debug}* | cut -d '/' -f 1|uniq -c >> $sixo

	echo_request "TIMED OUT ASYNC READS" $sixo
	egrep -ciR 'Timed out async read from org.apache.cassandra.io.sstable.format.AsyncPartitionReader' ./ --include={system,debug}* >> $sixo

	echo_request "WRITES.WRITE ERRORS" $sixo
	egrep -ciR 'Unexpected error during execution of request WRITES.WRITE' ./ --include={system,debug}* >> $sixo

	echo_request "WRITES.WRITE BACKPRESSURE" $sixo
	egrep -ciR 'backpressure rejection.*WRITES.WRITE' ./ --include={system,debug}* >> $sixo

	echo_request "READS.READ BACKPRESSURE" $sixo
	egrep -ciR 'backpressure rejection.*READS.READ' ./ --include={system,debug}* >> $sixo

	echo_request "READS.READ ERRORS" $sixo
	egrep -ciR 'Unexpected error during execution of request READS.READ' ./ --include={system,debug}* >> $sixo

	echo_request 'THREADS WITH PENDING' $sixo
	echo "threads with higher than 0 pending threads" >> $sixo
	egrep -R "TPC/" ./ --include=debug.log | awk '{print $1,$3}' | sort | uniq | column -t | awk '!/N\/A/ && !/0$/' >> $sixo
}


function solr() {
	is_solr_enabled=`egrep "Search" ./Nibbler/Node_Status.out`
	if [ -z "$is_solr_enabled" ]
	then 
		return 1
	fi

	touch $solr_file
	echo "Solr greps" > $solr_file

	echo_request "SOLR DELETES" $solr_file
	egrep -iRc 'ttl.*scheduler.*expired' ./ --include={system,debug}* | egrep ":[1-9]" >> $solr_file

	h=`egrep -iRh 'max_docs_per_batch' ./ --include=dse.yaml | head -1 | awk '{print $2}'`
	echo_request "SOLR DELETES HITTING $h THRESHOLD" $solr_file
	egrep -icR "ttl.*scheduler.*expired.*$h" ./ --include={system,debug}* | egrep ":[1-9]" >> $solr_file

	echo_request "SOLR AUTOCOMMIT" $solr_file
	egrep -icR 'commitScheduler.*DocumentsWriter' ./ --include={system,debug}* | egrep ":[1-9]" >> $solr_file

	echo_request "SOLR COMMITS BY CORE" $solr_file
	egrep -iR 'AbstractSolrSecondaryIndex.*Executing soft commit' ./ --include={system,debug}* | awk '{print $1,$(NF)}' | sort | uniq -c >> $solr_file

	echo_request "COMMITSCHEDULER" $solr_file
	egrep -Ri "index workpool.*Solrmetricseventlistener" ./ --include=debug.log | awk -F']' '{print $1}' | awk -F'Index' '{print $1}' | sort | uniq -c >> $solr_file

	echo_request "SOLR FLUSHES" $solr_file
	egrep -iR 'Index WorkPool.Lucene flush' ./ --include={system,debug}* | awk -F'[' '{print $2}' | awk '{print $1}' | sort | uniq -c >> $solr_file

	echo_request "SOLR FLUSHES BY THREAD" $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | sed 's/[0-9]*//g' | sed 's/\-/ /g'|  sort | uniq -c | sort >> $solr_file

	echo_request "SOLR FLUSH SIZE" $solr_file
	echo "0 - 999kB" >> $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=0.0 && $1<1){print $1,$2}' | wc -l >> $solr_file
	echo "1MB - 9MB" >> $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=1 && $1<10){print $1,$2}' | wc -l >> $solr_file
	echo "10MB - 49MB" >> $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=10 && $1<50){print $1,$2}' | wc -l >> $solr_file
	echo "50MB - 249MB" >> $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=50 && $1<250){print $1,$2}' | wc -l >> $solr_file
	echo "250MB - 1G" >> $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=250 && $1<=1000){print $1,$2}' | wc -l >> $solr_file
	echo "1G plus" >> $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=1000){print $1,$2}' | wc -l >> $solr_file

	echo_request "LARGEST 5 SOLR FLUSHES" $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '{print $1,$2}' | sort -r | head -5 >> $solr_file

	#flushing issues
	echo_request "FLUSHING FAILURES" $solr_file
	egrep -iR "Failure to flush may cause excessive growth of Cassandra commit log" ./ --include={system,debug}* >> $solr_file

	echo_request "QUERY RESPONSE TIMEOUT" $solr_file
	grep -R "Query response timeout of" ./ --include={system,debug}* >> $solr_file

	echo_request "LUCENE MERGES" $solr_file
	echo "total lucene merges" >> $solr_file
	grep -ciR "Lucene merge" ./ --include={system,debug}* | egrep ":[1-9]" >> $solr_file

	echo >> $solr_file
	echo "100ms - 249ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.100 && $1<0.250){print $1}' | wc -l >> $solr_file

	echo "250ms - 499ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.250 && $1<0.500){print $1}' | wc -l >> $solr_file

	echo "500ms - 999ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.500 && $1<1){print $1}' | wc -l >> $solr_file

	echo "1s plus" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=1){print $1}' | wc -l >> $solr_file

	# you see above there that NTR is kicking in.. glorified backpressure but not yet hitting backpressure just slowing down commit rate
	echo_request "INCREASING SOFT COMMIT RATE - Increasing commit rate before backpressure actually kicks in" >> $solr_file
	egrep -iR "Increasing soft commit max time" ./ --include={system,debug}* >> $solr_file

	# filter cache eviction
	echo_request "FILTER CACHE EVICTION" $solr_file
	egrep -iR "Evicting oldest entries" ./ --include={system,debug}* >> $solr_file

	# filter cache loading issue
	# In case Johnny mentioned , we don’t see fq getting used but 
	# as token ranges use fq, that is still a fit.
	# high execute latency
	# Customer uses RF=N setup. In that setup there is a known problem in 5.1.12: DSP-19800
	# The scenario is as follows:
	# A node becomes unhealthy for some reason. May be even slightly unhealthy.
	# As a result it starts redirecting (coordinating) 
	# queries to another nodes. In due process it needlessly 
	# requests to use an internal token filter on remote nodes. 
	# This filter is not available, as it is normally not used in 
	# RF=N configurations and must be loaded. Loading may take many 
	# minutes on large indexes. As a result all these queries time out.
	echo >> $solr_file
	echo "execute latency" >> $solr_file
	grep -R "minutes because higher than" ./ --include={system,debug}* >> $solr_file

	echo_request "SPERF QUERYSCORE" $solr_file
	sperf search queryscore >> $solr_file

	echo_request "SPERF FILTER CACHE" $solr_file
	sperf search filtercache >> $solr_file
}


function greps() {
	touch $warn
	echo > $warn
	touch $error
	echo > $error
	touch $threads
	echo > $threads
	touch $slow_queries
	touch $tombstone_file
	touch $histograms

	echo_request "DROPPED MESSAGES" 
	egrep -icR 'DroppedMessages.java' ./ --include={system,debug}* | egrep ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "POSSIBLE NETWORK ISSUES" 
	grep -ciR 'Unexpected exception during request' ./ --include={system,debug}* | egrep ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file
	
	echo_request "HINTED HANDOFFS TO ENDPOINTS" 
	grep -R 'Finished hinted handoff' ./ --include={system,debug}* | awk -F'endpoint' '{print $2}' | awk '{print $1}' | sort | uniq -c | sort >> $grep_file

	# echo_request "COMMIT-LOG-ALLOCATE FLUSHES - TODAY" 
	# egrep -ciR 'commit-log-allocator.*$today.*enqueuing' ./ --include={debug,output}* | sort -k 1 | awk -F':' '{print $1,$2}' | column -t >> $grep_file

	echo_request "FLUSHES BY THREAD" 
	egrep -iRh 'enqueuing flush of' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | awk -F'(' '{print $1}' | awk -F'-' '{print $1}' | sort | uniq -c | sort >> $grep_file
	# echo_request "FLUSHES BY THREAD - TODAY" 
	# egrep -iRh '$today.*enqueuing flush of' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | sort | uniq -c >> $grep_file

	echo_request "LARGEST 20 FLUSHES" 
	egrep -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | sort -h | tail -r -20 >> $grep_file

	# echo_request "SMALLEST 10 FLUSHES" 
	# egrep -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | sort -h | head -10 >> $grep_file

	echo_request "FLUSHING LARGEST"
	echo "Any flushes larger than .9x" >> $grep_file
	egrep -R "Flushing largest.*\.[8-9][0-9]" ./ --include=debug.log >> $grep_file

	# echo_request "AVERAGE FLUSH SIZE" 
	# egrep -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | awk 'BEGIN {p=1}; {for (i=1; i<=NF;i++) total = total+$i; p=p+1}; END {print sprintf("%.0f", total/p)}' | awk '{ byte =$1 /1024/1024; print byte " MB" }' >> $grep_file
	echo_request "TOTAL COMPACTIONS" 
	egrep -ciR 'Compacted' ./ --include={system,debug}* | sort -k 1 | egrep ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	# echo_request "TOTAL COMPACTIONS IN LAST DAY" 
	# egrep -ciR '$today.*Compacted' ./ --include={system,debug}* | sort -k 1 >> $grep_file

	# shows the number of compactions by table
	# 34113 [ disk3 c_data srm ts_sample-a35ac480045811ebab44a71fdbae4c86
	echo_request "TABLES COMPACTED"
	egrep -R "Compacted\ \(" ./ --include=debug.log | awk -F'sstables to ' '{print $2}' | awk -F',' '{print $1}' | sed 's/\// /g' | awk '{$NF=""; print $0}' | sort | uniq -c | sort -hr | head -10 >> $grep_file

	# measures the longest compactions times, not by node, just overall
	# [/disk3/c_data/srm/ts_sample-a35ac480045811ebab44a71fdbae4c86/nb-1882706-big,] 5,829,323ms
	echo_request "LONGEST COMPACTION TIMES"
	egrep -R "Compacted\ \(" ./ --include=debug.log | egrep -o "\[\/.*?\,.*\dms" | awk '{print $1,$(NF)}' | sort -h -k2 -r | head -20 >> $grep_file

	# measures the longest compaction times with node info
	# .//nodes/10.36.27.157/logs/cassandra/debug.log	5,829,323ms
	echo_request "LONGEST COMPACTION TIMES WITH NODE INFO"
	egrep -R "Compacted\ \(" ./ --include=debug.log | egrep -o ".*?\,.*\dms"  | awk '{print $1,$NF}' | sed 's/:.* /\t/g' | sort -h -r -k2 | head -20 | sort -k2 -r -h | column -t >> $grep_file

	echo_request "RATE LIMITER APPLIED"
	echo "Usually means too many operations, check concurrent reads/writes in c*.yaml" >> $grep_file
	egrep -R "RateLimiter.*currently applied" ./ --include={system,debug}* >> $grep_file

	echo_request "GC - OVER 100ms" 
	egrep -ciR 'gc.*\d\d\dms' ./ --include={system,debug}* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "GC - OVER 100ms TODAY" 
	egrep -ciR '$(date +%Y-%m-%d).*gc.*\d\d\dms' ./ --include={system,debug}* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "GC - GREATER THAN 1s" 
	egrep -ciR 'gc.*\d\d\d\dms' ./ --include={system,debug}* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_file

	echo_request "GC - GREATER THAN 1s TODAY" 
	egrep -ciR '$(date +%Y-%m-%d).*gc.*\d\d\d\dms' ./ --include={system,debug}* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_file

	echo_request "GC GREATER THAN 1s AND BEFORE" 
	egrep -iR -B 5 'gc.*\d\d\d\dms' ./ --include={system,debug}* >> $grep_file

	echo_request "TOMBSTONE TABLES" 
	egrep -iRh 'readcommand.*tombstone' ./ --include={system,debug}* | awk -F'FROM' '{print $2}' | awk -F'WHERE' '{print $1}' | sort | uniq -c | sort -nr >> $grep_file

	echo_request "TOMBSTONE MAX COUNT BY TABLE"
	egrep -iRh 'tombstone' ./ --include={system,debug}*  | grep -o 'scanned over.*\|live rows and.*' | awk '{print $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13}' | awk '{for (I=1;I<NF;I++) if ($I == "FROM") print $2, $(I+1)}' | sort -nrk1 | awk '!seen[$2]++' >> $grep_file

	echo_request "TOMBSTONE ALERTS BY NODE"
	egrep -ciR 'tombstone' ./ --include={system,debug}* | egrep ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "TOMBSTONE QUERY ABORTS BY TABLE"
	egrep -iRh 'tombstone' ./ --include={system,debug}* | grep "aborted" | awk '{for (I=1;I<NF;I++) if ($I == "FROM") print $(I+1)}' | sort | uniq -c >> $grep_file

	echo_request "TOMBSTONE PARTITIONS" $tombstone_file
	egrep -R "tombstone cells for" ./ --include={system.log,debug.log} | awk -F'FROM' '{print $2}' | awk -F'LIMIT' '{print $1}' | sort | uniq -c >> $tombstone_file

	echo_request "SLOW QUERIES" $slow_queries
	egrep -iR 'select.*slow' ./ --include={system,debug}* >> $slow_queries

	schema_file=$(find . -name schema | head -1)
	if [ ! -z "$schema_file" ]
	then
		echo_request "SSTABLE COUNT" 
		egrep -Rh -A 1 'Table:' ./ --include=cfstats | awk '{key=$0; getline; print key ", " $0;}' | sed 's/[(,=]//g' | awk '$5>30 {print $1,$2,$3,"\t",$4,$5}' | column -t >> $grep_file

		echo_request "PENDING TASKS" 
		egrep -iR '^-\ ' ./ --include=compactionstats >> $grep_file

		cp $schema_file "Nibbler/1-schema.out"
	fi

	echo_request "MERGED COMPACTIONS COUNT"
	egrep -Ric 'Compacted (.*).*]' ./ --include={debug,system}* | egrep ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "MERGED COMPACTIONS" 
	egrep -R 'Compacted (.*).*]' ./ --include={debug,system}* | awk '$0 ~ /[1-9][0-9]\ sstables/{print $0}' >> $grep_file

	echo_request "MERGED COMPACTIONS - TODAY" 
	egrep -R '$today.*Compacted (.*).*]' ./ --include={debug,system}* | awk '$0 ~ /[1-9][0-9]\ sstables/{print $0}' >> $grep_file

	# echo_request "ALERT CLASSES" 
	# egrep -R 'WARN|ERROR' --include={system,debug}* ./ | awk -F']' '{print $1}' | awk -F[ '{print $2}' | sed 's/[0-9:#]//g' | sort | uniq -c >> $grep_file



	driver_file=$(find . -name driver | tail -1) 
	if [ ! -z $driver_file ]
	then
		echo_request "REPAIRS" 
		egrep -iR 'Launching' ./ --include=opscenterd.log | egrep -o '\d{1,5}.*time to complete' | cut -d' ' -f5-60 | sort | uniq >> $grep_file

		echo_request "NTP" 
		egrep -iR 'time correct|exit status' ./ --include=ntpstat | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

		echo_request "LCS TABLES"
		egrep -iR "create table|and compaction" $driver_file --include=schema| grep -B1 "LeveledCompactionStrategy" >> $grep_file

		echo_request "KS REPLICATION I" 
		echo "$driver_file" >> $grep_file
		egrep -iR 'create keyspace' $driver_file --include=schema | cut -d ' ' -f 3-40 | awk -F'AND' '{print $1}' | column -t | sort -k8 >> $grep_file
		
		echo_request "KS REPLICATION II" 
		egrep -iR 'create keyspace' $driver_file --include=schema | cut -d ' ' -f 3-40 | awk -F'AND' '{print "ALTER KEYSPACE",$1}' | sort -k1 >> $grep_file
	fi

	echo_request "PREPARED STATEMENTS DISCARDED"
	egrep -Rc "prepared statements discarded" ./ --include={system,debug}* | egrep ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "AGGREGATION QUERY USED WITHOUT PARTITION KEY"
	egrep -ciR 'Aggregation query used without partition key' ./ --include={system,debug}* | egrep ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "CHUNK CACHE ALLOCATION"
	egrep -ciR "Maximum memory usage reached.*cannot allocate chunk of" ./ --include={system,debug}* | egrep ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t  >> $grep_file

	echo_request "ERRORS" $error
	egrep -R "ERROR" ./ --include={system,debug}* >> $error

	echo_request "WARN" $warn
	egrep -R "WARN" ./ --include={system,debug}* >> $warn

	# echo_request "THREADS" $threads
	# echo "All threads from system and debug logs" >> $threads
	# egrep -R ".*" ./ --include={system,debug}* | awk -F'[' '{print $2}' | awk -F']' '{print $1}' | sed 's|:.*||g' | sed 's|[(#].*||g' | sed 's/Repair-Task.*/Repair-Task/g' | sort -k2 | uniq -c | sort -k1 -n -r >> $threads

	echo_request "DROPPED" $drops
	echo "All dropped messages (mutation, read, hint)" >> $drops
	egrep -R "messages were dropped in last" ./ --include={system,debug}* >> $drops
}

function histograms_and_queues() {
	echo_request "CFHistograms > 1s" $histograms
	egrep -iR "histograms" -A 9 ./ --include={cfhistograms,commands.txt} | egrep "Max.*\d\d\d\d\d\d\d\." -B 9 >> $histograms

	echo_request "Proxyhistograms > 1s" $histograms
	egrep -iR "histograms" -A 9 ./ --include={proxyhistograms,commands.txt} | egrep "Max.*\d\d\d\d\d\d\d\." -B 9 >> $histograms

	echo_request "Latency waiting in Queue" $queues
	echo "Track if a queue is high from tpstats. We're looking for anything over 300ms" >> $queues
	echo "                                Message type           Dropped                  Latency waiting in queue (micros)                                    
                                                                                50%               95%               99%               Max" >> $queues
	echo "" >> $queues
	egrep -R "Latency waiting in queue" -A 20 ./ --include=tpstats | egrep ".*[3-9]\d\d\d\d\d\." >> $queues
}


function diag-import() {
	filename=$1
	python3 ~/Downloads/1-scripts/diag-import-main/import $filename
	python3 ~/Downloads/1-scripts/diag-viewer-main/app.py "$filename/diagnostics.db"
}

function iostat() {
	i=0
	for f in `find ./ -name iostat`;
		do 
			if [ $i -eq 0 ]
			then
				touch $iostat
				echo > $iostat
			fi
			i=1
			echo $f >> $iostat
			sperf sysbottle $f >> $iostat
		done
}

function use_options() {
	echo "Please specify an option:"
	echo "-a - nibbler, solr, config, greps"
	echo "-c - config only"
	echo "-d - diag-import"
	echo "-g - greps only"
	echo "-n - nibbler only"
	echo "-o - six0"
	echo "-s - solr only"
}

# # ========================= cassandra.yaml differ =========================
# rm "${grep_file}/cassandra.yaml.diff"

# for f in $(find ./ -type file -name cassandra.yaml); 
# do 
# egrep -o "^[a-zA-Z].*" $f | sort > "${f}.sorted"
# done

# previous_file=""
# i=0
# for f in $(find ./ -type file -name cassandra.yaml.sorted); 
# do
# if [ $i -eq 0 ]
# then 
# previous_file=$f
# else
# echo "=====================================" >> $grep_file/cassandra.yaml.diff
# echo $f >> $grep_file/cassandra.yaml.diff
# echo $previous_file >> $grep_file/cassandra.yaml.diff
# diff $previous_file $f >> $grep_file/cassandra.yaml.diff
# fi
# i=1
# done



# echo >> $grep_file
# echo >> $grep_file
# echo "************ ADDITIONAL ************" >> $grep_file


# Get the first schema, and check partition keys
# to see if they're the same or not and count them
# echo_request "same primary key - data density skewed" 
# egrep -ihR 'create table|primary key \(' $(find . -name schema | head -1) | sed 'N;s/\n/ /' | sed 's/CREATE\ TABLE/ /g' | sed 's/PRIMARY\ KEY/ /g' | column -t | sort -k 3

# using awk to search
# awk '/CREATE TABLE/{print $1,$2,$3," with read_repair_chance=0 and dclocal_read_repair_chance=0;"}' ./schema | sed 's/(//'

# get cfstats table sizes
#egrep -R "Keyspace|Table:|Space" . --include=cfstats


while true; do
	case $1 in 
	-a) 
		nibbler
		config
		solr
		greps
		iostat
		histograms_and_queues
		# sixO
		break
		;;
 	-c) 
		config
		break
		;;
	-d) 
		diag-import $1
		break
		;;
    -g)
    	greps
    	break
    	;; 
    -n) 
		nibbler
		break
		;;
	-o) 
		sixO
		break
		;;
	-s) 
		solr
		break
		;;
	*) 
		use_options
		exit 1
		;;
  esac
done


# run sperf on every diag
echo_request "SPERF DIAG" $$diag_file
sperf core diag >> $diag_file

echo_request "SPERF STATUS LOGGER" $sperf_file
sperf core statuslogger >> $sperf_file

echo_request "SPERF STATUS LOGGER - LATEST DAY ONLY" $sperf_file
sperf core statuslogger -st $today' 00:01:00,000' -et $today' 23:59:00,000' >> $sperf_file

echo_request "SPERF SLOW QUERY" $sperf_file
sperf core slowquery >> $sperf_file

echo_request "SPERF SCHEMA" $sperf_file
sperf core schema >> $sperf_file

sperf core gc >> $gcs
# end sperf stuff



# when done, ring the alert
echo "DONE"
tput bel





# from cqlsh tracing session, gather shard info:
# $grep "Processed response from shard" alln01-at-hcas18.txt |awk -F "," '{print $1}' |grep numFound | tr " " "*" | tr "\t" "&" |sed 's|*||g' |sed 's|Processedresponsefromshard||g'|sed 's|8609/solr/mfgsecurity.secure_events:||g' |sort -n |awk -F ":" '{print $1,$2,$3}'
# 173.36.27.225 numFound 105882
# 173.36.27.228 numFound 88308
# 173.36.27.234 numFound 94308


# traverse and unzip
# find ./ -name \*.zip -exec unzip {} \;
# for file in `find ./ -name *.zip`; do unzip $file; done


### key words
# JOINING: Finish joining ring
# Bootstrap completed for tokens


#mpstat parsing for tpc cores
#cat mpstats-eat-cassa08.log |awk '$4 > 95 {print $0}'

#cfstats write latencies
# grep -Hi -B15 "Local write latency:" ./nodetool/cfstats |egrep 'Table:|latency:' | grep -A2 "Table:" |grep -v "\-\-" |awk '{ printf("%-10s ",$0); if(NR%3==0) printf("\n");}'|sed 's/Local\ read\ latency:/read_latency/g' |sed 's/Local\ write\ latency:/write_latency/' | column -t | grep -v "NaN" | sort -r -k4 | sort -k7 -r

#top threads from ttop
# sperf ttop -c ttop-192.168.1.18.output | egrep -v "Total|RMI" | column -t | awk '$3 > 50 {print $0}'


# lcs tables
# egrep -iRh -B 2 -A 15 "level" ./10.36.81.120/ --include=cfstats | egrep "Table\:|level|read\ count|write\ count" | awk '{ printf("%-10s ",$0); if(NR%4==0) printf("\n");}' | column -t | awk '{print $NF,$0}' | sort -nr | cut -f2- -d' ' > LCS-tables.out

# awk '{ printf("%-10s ",$0); if(NR%3==0) printf("\n");}'


#replace in a file. Used for jpmc
# for f in `find ./ -name java_version`; do sed -i'' -e '1d' $f; done

