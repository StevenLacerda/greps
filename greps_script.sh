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
	today=$(find . -name "system.log" -o -name "debug.*"| head -1 $(head -1) | grep -oh "\d\d\d\d-\d\d-\d\d")
	java -jar ~/Downloads/~nibbler/Nibbler.jar ./
	cluster_config_summary="Cluster_Configuration_Summary.out"
	egrep -i ".*" $(find . -name version | head -1) >> $grep_file

	# echo "system.log start: " >> $grep_file
	system_log=$(find . -name system.log | head -1)
	if [ -z $system_log ]
	then
		system_log="null"
	fi
	echo "system.log start: " $(head -1 $system_log | grep -oh "\d\d\d\d-\d\d-\d\d") >> $grep_file


	debug_log=$(find . -name debug* | head -1)
	if [ -z $debug_log ]
	then
		debug_log="null"
	fi
	echo "debug.log start: " $(head -1 $debug_log | grep -oh "\d\d\d\d-\d\d-\d\d") >> $grep_file

	echo_request "NODE STATUS"
	cat $node_status >> $grep_file

	# config file section
	echo "DISK CONFIGURATION" >> $config_file
	egrep -Rh '======\ |^\s.*-' ./ --include=$cluster_config_summary | sed -e $'s/^====== /\\\n/g' >> $config_file

	echo >> $config_file
	echo "CONFIGURATION" >> $config_file 
	egrep -Rh '===== \d|Number|Machine' ./ --include=$cluster_config_summary | sed -e $'s/^====== /\\\n/g' >> $config_file
}


function config() { 
	touch $config_file
	echo > $config_file

	echo >> $config_file
	echo "YAML VALUES" >> $config_file
	for f in `find . -type file -name cassandra.yaml`;
	do
		echo $f | grep -o '[0-9].*[0-9]' >> $config_file
		egrep -ih "^memtable_|^concurrent_compactors|^commitlog_total|^compaction_" $f >> $config_file
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
}


function solr() {
	touch $solr_file
	echo "Solr greps" > $solr_file

	echo_request "SOLR DELETES" $solr_file
	egrep -iRc 'ttl.*scheduler.*expired' ./ --include={system,debug}* >> $solr_file

	h=`egrep -iRh 'max_docs_per_batch' ./ --include=dse.yaml | head -1 | awk '{print $2}'`
	echo_request "SOLR DELETES HITTING $h THRESHOLD" $solr_file
	egrep -icR "ttl.*scheduler.*expired.*$h" ./ --include={system,debug}* >> $solr_file

	echo_request "SOLR AUTOCOMMIT" $solr_file
	egrep -icR 'commitScheduler.*DocumentsWriter' ./ --include={system,debug}* >> $solr_file

	echo_request "SOLR COMMITS BY CORE" $solr_file
	egrep -iR 'AbstractSolrSecondaryIndex.*Executing soft commit' ./ --include={system,debug}* | awk '{print $1,$(NF)}' | sort | uniq -c >> $solr_file

	echo_request "COMMITSCHEDULER" $solr_file
	egrep -Ri "index workpool.*Solrmetricseventlistener" ./ --include=debug.log | awk -F']' '{print $1}' | awk -F'Index' '{print $1}' | sort | uniq -c >> $solr_file

	echo_request "SOLR FLUSHES" $solr_file
	egrep -iR 'Index WorkPool.Lucene flush' ./ --include={system,debug}* | awk -F'[' '{print $2}' | awk '{print $1}' | sort | uniq -c >> $solr_file

	echo_request "SOLR FLUSHES BY THREAD" $solr_file
	egrep -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | sed 's/[0-9]*//g' | sed 's/\-/ /g'|  sort | uniq -c >> $solr_file

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

	echo_request "QUERY RESPONSE TIMEOUT" $solr_file
	grep -cR "Query response timeout of" ./ --include={system,debug}* >> $solr_file

	echo_request "LUCENE MERGES" $solr_file
	echo "total lucene merges" >> $solr_file
	grep -ciR "Lucene merge" ./ --include={system,debug}* >> $solr_file

	echo >> $solr_file
	echo "100ms - 249ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.100 && $1<0.250){print $1}' | wc -l >> $solr_file

	echo "250ms - 499ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.250 && $1<0.500){print $1}' | wc -l >> $solr_file

	echo "500ms - 999ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.500 && $1<1){print $1}' | wc -l >> $solr_file

	echo "1s plus" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=1){print $1}' | wc -l >> $solr_file

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
}


function greps() {
	touch $grep_file

	echo_request "DROPPED MESSAGES" 
	egrep -icR 'DroppedMessages.java' ./ --include=debug.log >> $grep_file

	echo_request "POSSIBLE NETWORK ISSUES" 
	grep -ciR 'Unexpected exception during request' ./ --include=system* >> $grep_file

	echo_request "HINTED HANDOFFS TO ENDPOINTS" 
	grep -R 'Finished hinted handoff' ./ --include={system,debug}* | awk -F'endpoint' '{print $2}' | awk '{print $1}' | sort | uniq -c  >> $grep_file

	echo_request "COMMIT-LOG-ALLOCATE FLUSHES" 
	egrep -ciR 'commit-log-allocator' ./ --include={system,debug,output}* | sort -k 1 | awk -F':' '{print $1,$2}' | column -t >> $grep_file

	echo_request "COMMIT-LOG-ALLOCATE FLUSHES - TODAY" 
	egrep -ciR 'commit-log-allocator.*$today' ./ --include={system,debug,output}* | sort -k 1 | awk -F':' '{print $1,$2}' | column -t >> $grep_file

	echo_request "FLUSHES BY THREAD" 
	egrep -iRh 'enqueuing flush of' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | sort | uniq -c >> $grep_file

	# echo_request "FLUSHES BY THREAD - TODAY" 
	# egrep -iRh '$today.*enqueuing flush of' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | sort | uniq -c >> $grep_file

	echo_request "LARGEST 5 FLUSHES" 
	egrep -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | sort -h | tail -5 >> $grep_file

	echo_request "SMALLEST 5 FLUSHES" 
	egrep -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | sort -h | head -5 >> $grep_file

	# echo_request "AVERAGE FLUSH SIZE" 
	# egrep -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | awk 'BEGIN {p=1}; {for (i=1; i<=NF;i++) total = total+$i; p=p+1}; END {print sprintf("%.0f", total/p)}' | awk '{ byte =$1 /1024/1024; print byte " MB" }' >> $grep_file
	echo_request "TOTAL COMPACTIONS" 
	egrep -ciR 'Compacted' ./ --include={system,debug}* | sort -k 1 >> $grep_file

	echo_request "TOTAL COMPACTIONS IN LAST DAY" 
	egrep -ciR '$today.*Compacted' ./ --include={system,debug}* | sort -k 1 >> $grep_file

	echo_request "PENDING TASKS" 
	egrep -iR '^-\ ' ./ --include=compactionstats >> $grep_file


	echo_request "GC - OVER 100ms" 
	egrep -ciR 'gc.*\d\d\dms' ./ --include=system* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_file

	echo_request "GC - OVER 100ms TODAY" 
	egrep -ciR '$(date +%Y-%m-%d).*gc.*\d\d\dms' ./ --include=system* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_file

	echo_request "GC - GREATER THAN 1s" 
	egrep -ciR 'gc.*\d\d\d\dms' ./ --include=system* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_file

	echo_request "GC - GREATER THAN 1s TODAY" 
	egrep -ciR '$(date +%Y-%m-%d).*gc.*\d\d\d\dms' ./ --include=system* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_file

	echo_request "GC GREATER THAN 1s AND BEFORE" 
	egrep -iR -B 5 'gc.*\d\d\d\dms' ./ --include=system* >> $grep_file

	echo_request "TOMBSTONE TABLES" 
	egrep -iRh 'readcommand.*tombstone' ./ --include=system* | awk -F'FROM' '{print $2}' | awk -F'WHERE' '{print $1}' | sort | uniq -c | sort -nr >> $grep_file

	echo_request "TOMBSTONES BY NODE" 
	egrep -ciR 'readcommand.*tombstone' ./ --include=system* >> $grep_file

	echo_request "SSTABLE COUNT" 
	egrep -Rh -A 1 'Table:' ./ --include=cfstats | awk '{key=$0; getline; print key ", " $0;}' | sed 's/[(,=]//g' | awk '$5>30 {print $1,$2,$3,"\t",$4,$5}' | column -t >> $grep_file

	echo_request "TABLE COMPACTION STRATEGY" 
	schema_file=$(find . -name schema* | head -1)
	if [ -z schema_file ]
	then
		egrep -hi 'CREATE TABLE|compaction =' $schema_file | grep -v 'SizeTiered' >> $grep_file
	fi

	echo_request "MERGED COMPACTIONS COUNT"
	egrep -Ric 'Compacted (.*).*]' ./ --include={debug,system}* >> $grep_file

	echo_request "MERGED COMPACTIONS" 
	egrep -R 'Compacted (.*).*]' ./ --include={debug,system}* | awk '$0 ~ /[1-9][0-9]\ sstables/{print $0}' >> $grep_file

	echo_request "MERGED COMPACTIONS - TODAY" 
	egrep -R '$today.*Compacted (.*).*]' ./ --include={debug,system}* | awk '$0 ~ /[1-9][0-9]\ sstables/{print $0}' >> $grep_file

	# echo_request "ALERT CLASSES" 
	# egrep -R 'WARN|ERROR' --include={system,debug}* ./ | awk -F']' '{print $1}' | awk -F[ '{print $2}' | sed 's/[0-9:#]//g' | sort | uniq -c >> $grep_file

	echo_request "NTP" 
	egrep -iR 'time correct|exit status' ./ --include=ntpstat >> $grep_file

	echo_request "REPAIRS" 
	egrep -iR 'Launching' ./ --include=opscenterd.log | egrep -o '\d{1,5}.*time to complete' | cut -d' ' -f5-25 | sort | uniq >> $grep_file

	echo_request "PROXYHISTOGRAMS" 
	egrep -R 'Max' ./ --include=proxyhistograms | awk 'BEGIN{print "Node","Read","Write","Range","CASRead","CASWrite","ViewWrite"};{print $1,$2,$3,$4,$5,$6,$7,$8}' | column -t >> $grep_file


	driver_file=$(find . -name driver* | tail -1)
	if [ ! -z driver_file ]
	then
		echo_request "KS REPLICATION I" 
		echo "$driver_file" >> $grep_file
		egrep -iR 'create keyspace' $driver_file --include=schema | cut -d ' ' -f 3-40 | awk -F'AND' '{print $1}' | column -t | sort -k8 >> $grep_file
		echo_request "KS REPLICATION II" 
		egrep -iR 'create keyspace' $driver_file --include=schema | cut -d ' ' -f 3-40 | awk -F'AND' '{print $1}' >> $grep_file
	fi
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
		sixO
		;;
 	-c) 
		config
		;;
    -g)
    	greps
    	;; 
    -n) 
		nibbler
		;;
	-o) 
		sixO
		;;
	-s) 
		solr
		;;
  esac
done


# run sperf on every diag
echo_request "SPERF DIAG" $$diag_file
sperf core diag >> $diag_file

echo_request "SPERF QUERYSCORE" $solr_file
sperf search queryscore >> $solr_file

echo_request "SPERF STATUS LOGGER" $sperf_file
sperf core statuslogger >> $sperf_file &

echo_request "SPERF STATUS LOGGER - LATEST DAY ONLY" $sperf_file
sperf core statuslogger -st $today' 00:01' -et $today' 23:59' >> $sperf_file &

echo_request "SPERF SLOW QUERY" $sperf_file
sperf core slowquery >> $sperf_file &

echo_request "SPERF SCHEMA" $sperf_file
sperf core schema >> $sperf_file &
# end sperf stuff



# when done, ring the alert
echo "DONE"
tput bel





### key words
# JOINING: Finish joining ring
# Bootstrap completed for tokens
