Just a script of greps added over time. Run the script by putting it in your path, and then:

From inside a diag tarball, which can be anything. Will read any debug.log and system.log file in the
directory recursively:

greps [options]

Possible options are:

-a - nibbler, solr, config, greps


-c - config only

-d - diag-import

-g - greps only

-n - nibbler only

-o - six0

-s - solr only


There are some options which are located at the bottom of the file and constantly get changed and added to,
so refer to the bottom of the greps.sh file to gather the options available.

You will need both Nibbler and Sperf in your path as well, as the script relies on them.
