Just a script of greps added over time. Run the script by putting it in your path, and then:

From inside a diag tarball, which can be anything. Will read any debug.log and system.log file in the
directory recursively:

greps [options]

Possible options are (in normal scenarios, when you have a full diag, just run _greps -a_):

-a 
  nibbler,
  config,
  solr,
  greps,
  iostat,
  histograms_and_queues,
  tombstones

-c config

-g greps, tombstones

-n nibbler

-o six0

-s solr


There are some options which are located at the bottom of the file and constantly get changed and added to,
so refer to the bottom of the greps.sh file to gather the options available.

You will need both Nibbler and Sperf in your path as well, as the script relies on them:

https://github.com/riptano/Nibbler

https://github.com/riptano/support_performance

They will need to be in your path so that sperf and nibbler commands work from the script.
