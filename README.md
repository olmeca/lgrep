# **lgrep**
A variation on grep, targeting log files

**lgrep** is a variation on **grep**, developed specifically for efficient searching through application log files. Though most of the time an entry in a log file consists of one line, sometimes it spans multiple lines. A log entry usually consists of some metadata (e.g date, time, code reference) and a message. Sometimes the message part takes up multiple lines, e.g. if it contains a whole JSON object or a whole stack trace.

## The problem
When filtering log entries from log files I would usually want to keep every log entry intact, even if it spans several lines. Tools like **grep**, **sed** perform selection on a per line basis, so if you for instance use grep, you will get only one line of every multiline log entry.

## The solution
In the common cases of multiline log entries (JSON or XML message, stack trace) it is usually quite easy to recognize the whole log entry. This is because log entries normally start with a fixed set of metadata fields. In case of a multiline message usually the additional message lines are easily distinguishable from the main log entry line. If we could tell grep how to make this distinction then it would be able to treat a multiline log entry as one unit. This is the basis for **lgrep**: it takes as an extra argument a regex that matches only the first line - the main line - of a log entry. As this regex is a quite static value in normal use cases, it is also possible to define it as an environment variable. So you have two options:
- a command line argument:
  ```
  lgrep -e="<pattern that matches the start of a log entry>" ...
  ```
- an environment variable:
  ```
  export LGREP_ENTRY="<pattern that matches the start of a log entry>"
  lgrep ...
  ```

For now, lgrep -h is your friend:
```
  usage: lgrep [options] <regex patterns> <file name>
  
  e.g.   lgrep -i="Exception:" -x="DEBUG" server.log
  
  This will select all entries containing the string "Exception", but
  excluding those that also contain the string "DEBUG".
  
  lgrep is a variation on grep, intended for searching through application
  log files. It makes a distinction between 'log entries' and 'sublines'. 
  A log entry usually consists of some metadata items and a message and 
  the whole entry is usually printed as one line.
  But sometimes the message part contains several lines, like e.g.
  a stack trace or an XML or JSON message. Using normal grep in such cases
  you only get the first line of the messages. Other lines are filtered out
  by grep. Here is where lgrep does a better job, by returning the complete
  log entry (including sub lines) for every match.
  The search for the regex is performed only on the first line of a log entry,
  but the search result for a matching main line includes its
  sublines. 
  In order to distinguish log entry lines from sublines lgrep needs some
  extra information. It needs an extra regex pattern that matches the
  first line of every log entry. This pattern can be passed as a command line
  option. But as this pattern is usually invariable for a specific application,
  you can also define it as an environment variable.
  Furthermore, because log file analysis usually involves multiple pattern
  matches and because log files are usually huge, lgrep will take multiple
  patterns as command line options and apply all in one go.
  Another characteristic of log file analysis is that oftentimes the focus
  is on a specific period of time. Log entries normally contain timestamps,
  so why not be able to express the time range of interest? This can be
  done by passing optional start time and end time regex patterns as
  command line arguments.
  
  Options 
    -i=<pattern> or --include=<pattern> e.g. -i=ERROR
    Specifies a regex pattern. Entries that don't match the pattern will
    not be included in the result set. The pattern is only applied to the
    first line of every log entry, as that is where the metadata and main
    message part are found. 
    Multiple patterns can be specified on the command line by repeating 
    '-i=<pattern1> -i=<pattern2>'. A log entry will have to match 
    all patterns specified to be included in the result set.
    
    -I=<pattern> or includeIgnorecase=<pattern> e.g. -I=debug -I="\[debug\]"
    Specifies a regex pattern to be applied ignoring character case.
    Apart from that this pattern is treated equally to a -i pattern.
    
    -x=<pattern> or --exclude=<pattern e.g. -x="status=OK"
    Specifies a regex pattern. Entries that match the pattern will be
    excluded from the result set.
    Multiple patterns can be specified on the command line by repeating 
    '-x=<pattern1> -x=<pattern2>'. A log entry will have to match 
    all patterns specified to be included in the result set.
    
    -X=<pattern> or --excludeIgnoreCase=<pattern>
    Specifies a regex pattern to be applied ignoring character case.
    Apart from that this pattern is treated equally to a -x pattern.
    
    -e=<pattern> or --entry=<pattern>
    Specifies a regex pattern that matches the first line of every 
    log entry. Used to distinguish the main log entry line from 
    lines that are part of the log message.
    Instead of specifying this pattern in every command, you can also
    set the environment variable LGREP_ENTRY to the pattern. E.g.
      export LGREP_ENTRY="^2017-03-15"
    if every log entry starts with that date string.
    
    -f=<pattern> or --from=<pattern>
    Used to specify the start of a range of interest within the log file.
    E.g. specify a timestamp regex. The part of the file before the first
    match of the regex will be suppressed from the output.
    
    t=<pattern> or --to=<pattern>
    Used to specify the end of a range of interest within the log file.
    E.g. specify a timestamp regex. The part of the file from the first
    match of the regex on will be suppressed from the output.
    
    -n or --numbers
    Prepend the line number to every line in the output.
    
    -m=<number> or --maxMatches:<number> e.g. -m=1
    Specifies the maximum number of entries to match.
    After finding the specified number of matches the process
    stops and returns the results found so far.
    
    -h or --help
    Displays this text.
    
    lgrep is based on PCRE (www.pcre.org).
```
