# greps

#### flushing
grep -ciR "commit-log-allocator" ./ --include=debug.log | sort -k 1

grep -iR "commit-log-allocator" ./ --include=debug.log

grep -iR "completed flushing" ./ --include=debug.log | cut -d'(' -f2 | cut -d')' -f1 | sort -h

egrep -R "SlabPoolCleaner.*Enqueuing flush" ./ --include=debug.log | egrep -oh "\d[1-10](KiB|MiB|GiB)" | sort -h

#### flushes per minute
grep -R 'Enqueuing flush' * --include=debug.log | egrep 'goid|metadata' | awk '{print $3, $4}' | cut -d: -f1,2 | uniq -c | awk '{print $2, $3 "\t" $1}'

#### compaction
grep -ciR "Compacted" ./ --include=debug.log | sort -k 1

egrep -iR "Compacting large row " ./ --include=debug.log

#### gc
egrep -ciR "gc.*\d\d\d\dms" ./ --include=debug.log | sort -k 1

egrep -ciR "gc.*\d\d\dms" ./ --include=debug.log | sort -k 1

egrep -iR "gc.*\d\d\dms" ./ --include=debug.log | cut -d " " -f 1,4,5,10-15 | column -t | sort -t '\t' -k1,1 -k2,3

#### network issues
grep -ciR "Unexpected exception during request" ./ --include=debug.log

#### file cache exhausted
grep -ciR "Maximum memory usage reached" ./ --include=debug.log | sort -k 1

#### WARN/ERROR
egrep -R "WARN|ERROR" --include=debug.log ./ | awk '{print $1,$5}' | sed 's/.*log://g' | sort | uniq -c

#### ntp
egrep -iR "time.*`date +"%Y"`" ./ --include=ntptime | awk '{print $1,$4,$5,$6,$7,$8}' | sed 's/,//g' | sort -k 1 | column -t

#### ttop
grep -i "CoreThread-" ./ttop-10.12.156.221-Thu\ Jul\ 23\ 15%3A59%3A23\ EDT\ 2020.output | rev | awk '{print $1}' | rev | sort -h | uniq -c

egrep "heap allocation rate" 172.22.7.81_ttop.log | grep -v "kb/s" | awk '{print $4}' | sort -h | tail -10


# SOLR

#### solr deletes
egrep -iR "ttl.*scheduler.*expired" ./ --include=debug.log

egrep -iR "ttl.*scheduler.*expired" ./ --include=debug.log | grep 4096

#### solr autocommit
egrep -iR "commitScheduler.*DocumentsWriter" ./ --include=debug.log

#### StatusLogger
egrep -iR "StatusLogger.java:86" ./ --include=system.log | awk -F'StatusLogger' '{print $2}' | awk '$4>0 {print $3,"\t",$4}' | column -t

#### Keyspaces
egrep -iR "create keyspace" ./ --include=schema | cut -d " " -f 3-13 | awk '{print $1,$8,$9,$10}' | sed -E 's/AND|{|}//g' | sort -k 8 | uniq | column -t


# SPARK
#### grab bytes sent to driver from executor
egrep -R "sent to driver" ./100.99.209.224.workerlog/ | awk -F ')' '{print $2}' | awk '{print $2}' | awk '{for (i=1; i<=NF;i++) total = total+$i}; END {print total}'



# Generic
#### Adding columns
egrep java oom.rtf | grep -v Out | awk -F'kernel' '{print $2}' | awk '{print $7}' | awk '{for (i=1; i<=NF;i++) total = total+$i}; END {print total}'
