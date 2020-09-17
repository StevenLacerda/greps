# greps

#### flushing
grep -ciR "commit-log-allocator" ./ --include={system,debug}* | sort -k 1 | awk -F":" '{print $1,$2}' | column -t

grep -iR "commit-log-allocator.*[0-9][0-9]-[0-9][0-9]" ./ --include={system,debug}\* | cut -d" " -f1,3 | sort -k1 | uniq -c

grep -iR "commit-log-allocator" ./ --include={system,debug}* | sort -k 1,2 -k2,3

grep -iR "completed flushing" ./ --include={system,debug}* | cut -d'(' -f2 | cut -d')' -f1 | sort -h | tail -5

###### largest 5 flushes
grep -iR "enqueuing flush of" ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F' ' '{print $4}' | sort -h | tail -5

###### largest flush by table
grep -iR "enqueuing flush of" ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F' ' '{print $3,$4}' | sort -r | sort -u -t: -k1,1

###### flushes by table
grep -iR "enqueuing flush of" ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F' ' '{print $3}' | sort | uniq -c

###### flushes by thread
grep -iRh "enqueuing flush of" ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/\:.*//g' | sort | uniq -c

#### compaction
grep -ciR "Compacted" ./ --include={system,debug}* | sort -k 1

egrep -iR "Compacting large row " ./ --include={system,debug}*

#### StatusLogger
egrep -iR "StatusLogger.java:86" ./ --include=system* | awk -F'StatusLogger' '{print $2}' | awk '$4>0 {print $3,"\t",$4}' | column -t

egrep -iR "StatusLogger.java:[86,56]" ./ --include=system* | awk -F'StatusLogger' '{print $2}' | awk '$4>0 {print $3,"\t",$4}' | column -t | sort

#### gc
egrep -ciR "gc.*\d\d\d\dms" ./ --include=system\* | sort -k 1

egrep -ciR "gc.*\d\d\dms" ./ --include=system\* | sort -k 1

egrep -iR "gc.*\d\d\dms" ./ --include=system\* | cut -d " " -f 1,4,5,6,10-15 | column -t | sort -t '\t' -k1,1 -k2,3

#### tombstones
egrep -iRh "readcommand.\*tombstone" ./ --include=system* | cut -d" " -f3-50

egrep -iR "maximum tombstones" ./ --include=cfstats | awk '$9>1 {print $2,$3,$4,$5,$6,$7,$8,$9}' | sort | uniq

egrep -iRh "readcommand.\*tombstone" ./ --include=system* | awk -F'FROM' '{print $2}' | awk -F'WHERE' '{print $1}' | sort | uniq

#### sstable count
egrep -iR "sstable count" ./ --include=cfstats | awk '$4>30 {print $1,$2,$3,"\t",$4}'

#### network issues
grep -ciR "Unexpected exception during request" ./ --include=system*

#### file cache exhausted
grep -ciR "Maximum memory usage reached" ./ --include=system* | sort -k 1

#### classes
egrep -R "WARN|ERROR" --include={system,debug}* ./ | awk '{print $1,$5}' | sed 's/.*log://g' | sort | uniq -c

egrep -R "INFO|DEBUG|WARN|ERROR|CRITICAL" --include={system,debug}* ./ | awk '{print $1,$5}' | sed 's/.*log://g' | sed 's/:.*//g' | sort | uniq -c

#### ntp
egrep -iR "time correct|exit status" ./ --include=ntpstat

#### repairs
egrep -iR "Launching" ./ --include=opscenterd.log | egrep -o "\d{1,5}.*time to complete" | cut -d" " -f5-25 | sort | uniq


# SOLR

#### solr deletes
egrep -iR "ttl.*scheduler.\*expired" ./ --include={system,debug}\*

egrep -iR "ttl.*scheduler.\*expired" ./ --include={system,debug}\* | grep 4096

#### solr autocommit
egrep -iR "commitScheduler.\*DocumentsWriter" ./ --include={system,debug}*



# SPARK
#### grab bytes sent to driver from executor
egrep -R "sent to driver" ./ --include=workerlog/ | awk -F ')' '{print $2}' | awk '{print $2}' | awk '{for (i=1; i<=NF;i++) total = total+$i}; END {print total}'



# Generic
#### Adding columns using awk - example
egrep java oom.rtf | grep -v Out | awk -F'kernel' '{print $2}' | awk '{print $7}' | awk '{for (i=1; i<=NF;i++) total = total+$i}; END {print total}'

#### Keyspaces
egrep -iR "create keyspace" ./ --include=schema | cut -d " " -f 3-21 | awk '{print $1,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21}' | sed -E 's/AND|{|}//g' | sort -k 8 | uniq | column -t

#### Tables with specific compaction strategies
egrep -i "create\ table|compaction" ./nodes/"$(ls ./nodes | head -1)"/driver/schema | egrep -B 1 TimeWindow | egrep -i table | column -t | awk '{print $3}'

egrep -i "create\ table|compaction" ./nodes/"$(ls ./nodes | head -1)"/driver/schema | egrep -B 1 LeveledCompaction | egrep -i table | column -t | awk '{print $3}'

#### ttop
grep -i "CoreThread-" ./ttop-10.12.156.221-Thu\ Jul\ 23\ 15%3A59%3A23\ EDT\ 2020.output | rev | awk '{print $1}' | rev | sort -h | uniq -c

egrep "heap allocation rate" 172.22.7.81_ttop.log | grep -v "kb/s" | awk '{print $4}' | sort -h | tail -10

### recursively unzip
find . -name "system*.zip" | while read filename; do unzip -o -d "`dirname "$filename"`" "$filename"; done;
