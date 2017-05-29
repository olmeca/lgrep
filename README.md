# **lgrep**
A variation on grep, targeting log files

**lgrep** is a variation on **grep**, intended for searching through application
log files. Though most of the time an entry in a log file consists of one line, sometimes an entry may take several lines. A log entry usually consists of a bunch of metadata (e.g date, time, code reference) and a message. Sometimes the message part can take multiple lines, e.g. if it contains a whole JSON object or a whole stack trace.

## The problem
When filtering log entries from log files I would usually want to keep every log entry intact, even if it consists of several lines. Tools like **grep**, **sed** have individual lines as their unit of work, so if you for instance use grep, you will get only one line of every multiline log entry.

## The solution
In the common cases of multiline log entries (JSON or XML message, stack trace) it is usually quite easy to recognize the whole log entry. This is because log entries normally start with a fixed set of metadata fields. In case of a multiline message usually the additional message lines are easily distinguishable from the main log entry line. If we could tell grep how to make this distinction then it would be able to treat a multiline log entry as one unit. This is the basis for **lgrep**: it takes as an extra argument a regex that matches only the first line - the main line - of a log entry. As this regex is a quite static value in normal use cases, it is also possible to define it as an environment variable. So you have two options:
- a command line argument:
  `lgrep -e="firstlineregexpattern" ...`
- an environment variable:
  ```
  export LGREP_ENTRY="firstlineregexpattern"
  lgrep ...
  ```

It makes a distinction between 'log entries' and 'sublines'. 
A log entry usually consists of some metadata items and a message. 
The whole entry is usually printed as one line.
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
