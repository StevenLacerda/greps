#!/bin/bash
# add a grep for chrony
# add a grep for average flush size
# add a grep for ERROR
# add a grep for timeout, timedout


mkdir Nibbler
grep_dir="Nibbler/greps.txt"
node_status="Nibbler/Node_Status.out"
cluster_config_summary="Nibbler/Cluster_Configuration_Summary.out"


while getopts d:a:f: flag
do
    case "${flag}" in
        d) mydate=${OPTARG};;
        a) age=${OPTARG};;
        f) fullname=${OPTARG};;
    esac
done

if [ -z "$mydate" ]
then
	echo $mydate
	$mydate=`date +%Y-%m-%d`
fi

# runs nibbler
java -jar ~/Downloads/~nibbler/Nibbler.jar ./


echo "version" > $grep_dir
egrep -i ".*" ./nodes/"$(ls ./nodes | head -1)"/nodetool/version >> $grep_dir


echo "system.log start: " >> $grep_dir
head -1 ./nodes/"$(ls ./nodes | head -1)"/logs/cassandra/system* | grep -oh "\d\d\d\d-\d\d-\d\d" >> $grep_dir

echo "debug.log start: " >> $grep_dir
head -1 ./nodes/"$(ls ./nodes | head -1)"/logs/cassandra/debug* | grep -oh "\d\d\d\d-\d\d-\d\d" >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
cat $node_status >> $grep_dir

echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "disk configuration" >> $grep_dir
egrep -R "======\ |^\s.*-" ./ --include=$cluster_config_summary >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "configuration" >> $grep_dir
egrep -Rh "===== \d|Number|Machine" ./ --include=$cluster_config_summary | sed 's/=//g' >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "sperf status logger" >> $grep_dir
sperf core statuslogger >> $grep_dir

echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "sperf status logger - one day only" >> $grep_dir
sperf core statuslogger -st "$mydate 00:01" -et "$mydate 23:59" >> $grep_dir


# echo >> $grep_dir
# echo "==========================================================================================================" >> $grep_dir
# echo "sperf status logger - last 3 days" >> $grep_dir
# sperf core statuslogger -st "$(date -v -3d '+%Y-%m-%d') 00:01" -et "$(date +%Y-%m-%d) 23:59" >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "sperf slow query" >> $grep_dir
sperf core slowquery >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "sperf schema" >> $grep_dir
sperf core schema >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "sperf diag" >> $grep_dir
sperf core diag >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "hinted handoffs to endpoint" >> $grep_dir
grep -R "$mydate.*Finished hinted handoff" ./ --include={system,debug}* | awk -F'endpoint' '{print $2}' | awk '{print $1}' | sort | uniq -c >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "possible network issue" >> $grep_dir
grep -ciR "$mydate.*Unexpected exception during request" ./ --include=system* >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "yaml values" >> $grep_dir
for f in `find ./ -type file -name cassandra.yaml`;
do
echo $f >> $grep_dir
egrep -iRh "^memtable_|^#memtable_|^concurrent_compactors|^#concurrent_compactors|^#commitlog_total|^commitlog_total" $f >> $grep_dir
echo 
done


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "commit-log-allocator flushes" >> $grep_dir
grep -ciR "commit-log-allocator" ./ --include={system,debug,output}* | sort -k 1 | awk -F":" '$2>0{print $1,$2}' | column -t >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "largest 5 flushes" >> $grep_dir
grep -iR "enqueuing flush of" ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | sort -h | tail -5 >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "smallest 5 flushes" >> $grep_dir
grep -iR "enqueuing flush of" ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | sort -h | head -5 >> $grep_dir


# echo >> $grep_dir
# echo "==========================================================================================================" >> $grep_dir
# echo "average flush size" >> $grep_dir
# grep -iR "enqueuing flush of" ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | awk 'BEGIN {p=1}; {for (i=1; i<=NF;i++) total = total+$i; p=p+1}; END {print sprintf("%.0f", total/p)}' | awk '{ byte =$1 /1024/1024; print byte " MB" }' >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "flushes by thread" >> $grep_dir
grep -iRh "enqueuing flush of" ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | sort | uniq -c >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "Total compactions" >> $grep_dir
grep -ciR "$mydate.*Compacted" ./ --include={system,debug}* | sort -k 1 >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "pending tasks" >> $grep_dir
egrep -iR "^-\ " ./ --include=compactionstats >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "gc's - over 100ms" >> $grep_dir
egrep -ciR "gc.*\d\d\dms" ./ --include=system* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "gc's - over 100ms today" >> $grep_dir
egrep -ciR "$(date +%Y-%m-%d).*gc.*\d\d\dms" ./ --include=system* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "gc's - greater than 1s" >> $grep_dir
egrep -ciR "gc.*\d\d\d\dms" ./ --include=system* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "gc's - greater than 1s today" >> $grep_dir
egrep -ciR "$(date +%Y-%m-%d).*gc.*\d\d\d\dms" ./ --include=system* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "gc's greater than 1s and before" >> $grep_dir
egrep -iR -B 5 "gc.*\d\d\d\dms" ./ --include=system* >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "tombstone tables" >> $grep_dir
egrep -iRh "readcommand.*tombstone" ./ --include=system* | awk -F'FROM' '{print $2}' | awk -F'WHERE' '{print $1}' | sort | uniq >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "sstable count" >> $grep_dir
egrep -Rh -A 1 "Table:" ./ --include=cfstats | awk '{key=$0; getline; print key ", " $0;}' | sed 's/[(,=]//g' | awk '$5>30 {print $1,$2,$3,"\t",$4,$5}' | column -t >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "table type" >> $grep_dir
egrep -h -A 1 "CREATE TABLE|compaction =" ./nodes/"$(ls ./nodes | head -1)"/driver/schema | awk '{key=$0; getline; print key ", " $0;}' | sed 's/[(,=]//g' | awk '$5>30 {print $1,$2,$3,"\t",$4,$5}' | column -t >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "merged compactions" >> $grep_dir
egrep -R "$mydate.*Compacted (.*).*]" ./ --include={debug,system}* | awk '$0 ~ /[1-9][0-9]\ sstables/{print $0}' >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "alert classes" >> $grep_dir
egrep -R "WARN|ERROR" --include={system,debug}* ./ | awk -F']' '{print $1}' | awk -F[ '{print $2}' | sed 's/[0-9:#]//g' | sort | uniq -c >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "ntp" >> $grep_dir
egrep -iR "time correct|exit status" ./ --include=ntpstat >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "repairs" >> $grep_dir
egrep -iR "Launching" ./ --include=opscenterd.log | egrep -o "\d{1,5}.*time to complete" | cut -d" " -f5-25 | sort | uniq >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "proxyhistograms" >> $grep_dir
egrep -R "Max" ./ --include=proxyhistograms | awk 'BEGIN{print "Node","Read","Write","Range","CASRead","CASWrite","ViewWrite"};{print $1,$2,$3,$4,$5,$6,$7,$8}' | column -t >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "keyspace replication with tabs" >> $grep_dir
egrep -iR "create keyspace" ./nodes/"$(ls ./nodes | head -1)"/driver --include=schema | cut -d " " -f 3-21 | awk -F'AND' '{print $1}' | column -t >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "keyspace replication" >> $grep_dir
egrep -iR "create keyspace" ./nodes/"$(ls ./nodes | head -1)"/driver --include=schema | cut -d " " -f 3-21 | awk -F'AND' '{print $1}' >> $grep_dir



echo "############## 6.x specific greps" >> $grep_dir
echo >> $grep_dir

echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "backpressure rejection" >> $grep_dir
grep -R 'Backpressure rejection while receiving' ./ --include={system,debug}* |cut -d '/' -f 1|uniq -c >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "timed out async reads" >> $grep_dir
grep -R 'Timed out async read from org.apache.cassandra.io.sstable.format.AsyncPartitionReader' */logs/cassandra/*|cut -d '/' -f 1|uniq -c

############## SOlR section

echo >> $grep_dir
echo "************** SOLR SECTION **************" >> $grep_dir
echo >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "solr deletes" >> $grep_dir
egrep -iRc "ttl.*scheduler.*expired" ./ --include={system,debug}* >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "solr deletes hitting 4096 threshold" >> $grep_dir
egrep -iR "ttl.*scheduler.*expired" ./ --include={system,debug}* | grep -c 4096 >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "solr autocommit" >> $grep_dir
egrep -icR "commitScheduler.*DocumentsWriter" ./ --include={system,debug}* >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "solr commits by core" >> $grep_dir
egrep -iR "AbstractSolrSecondaryIndex.*Executing soft commit" ./ --include={system,debug}* | awk '{print $1,$(NF)}' | sort | uniq -c >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "solr flushes" >> $grep_dir
egrep -iR "Index WorkPool.Lucene flush" ./ --include={system,debug}* | awk -F'[' '{print $2}' | awk '{print $1}' | sort | uniq -c >> $grep_dir


echo >> $grep_dir
echo "==========================================================================================================" >> $grep_dir
echo "sperf queryscore" >> $grep_dir
sperf search queryscore >> $grep_dir


# # ========================= cassandra.yaml differ =========================
# rm "${grep_dir}/cassandra.yaml.diff"

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
# echo "=====================================" >> $grep_dir/cassandra.yaml.diff
# echo $f >> $grep_dir/cassandra.yaml.diff
# echo $previous_file >> $grep_dir/cassandra.yaml.diff
# diff $previous_file $f >> $grep_dir/cassandra.yaml.diff
# fi
# i=1
# done





echo >> $grep_dir
echo >> $grep_dir
echo "************ Additional ************"


# Get the first schema, and check partition keys
# to see if they're the same or not and count them
# echo >> $grep_dir
# echo "same primary key - data density skewed" >> $grep_dir
# egrep -ihR "primary key \(" ./nodes/"$(ls ./nodes | head -1)"/driver/schema | sort | uniq -c >> $grep_dir

# using awk to search
# awk '/CREATE TABLE/{print $1,$2,$3," with read_repair_chance=0 and dclocal_read_repair_chance=0;"}' ./schema | sed 's/(//'


# when done, ring the alert
echo "DONE"
tput bel
