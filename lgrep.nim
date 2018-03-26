#[
MIT License

Copyright (c) 2017 Rudi Angela

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]#


import os
import parseopt2
import streams
import re
import parseutils
import "lgrep_lib"

const helptext = "lgrep - specialized grep for application log files" & """

  (c) 2017 Rudi Angela

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
    
    -x=<pattern> or --exclude=<pattern> e.g. -x="status=OK"
    Specifies a regex pattern. Entries that match the pattern will be
    excluded from the result set.
    Multiple patterns can be specified on the command line by repeating 
    '-x=<pattern1> -x=<pattern2>'. A log entry will have to match 
    at least one of the patterns specified to be excluded from the result set.
    
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
"""

proc writeHelp() = echo helptext


var filename: string = nil
var printLineNrs: bool = false
var maxMatches: uint = 9223372036854775807'u
var includeEntryLine: bool = true
var showOnlyLastSublineMatched: bool = false
var selectors: seq[Selector] = @[]
var entryLinePattern: string = getEnv("LGREP_ENTRY")
var subLinePattern: string = nil
var subLineSelector: Selector = nil
var debug: bool = false
var printHelp: bool = false
var file: File = nil
var fromRe: Regex = nil
var toRe: Regex = nil

for kind, key, val in getopt():
  case kind
  of cmdArgument:
    filename = key
  of cmdLongOption, cmdShortOption:
    case key
    of "help", "h":
      printHelp = true
    of "inclusionSelector", "i":
      selectors.add(Selector(invert: false, matcher: re(val)))
    of "inclusionSelectorIgnoreCase", "I":
      selectors.add(Selector(invert: false, matcher: re(val, {reIgnoreCase})))
    of "exclusionSelector", "x":
      selectors.add(Selector(invert: true, matcher: re(val)))
    of "exclusionSelectorIgnoreCase", "X":
      selectors.add(Selector(invert: true, matcher: re(val, {reIgnoreCase})))
    of "entryLinePattern", "e":
      entryLinePattern = val
    of "maxMatches", "m":
      discard parseuint(val, maxMatches)
    of "includeLineNumber", "n":
      printLineNrs = true
    of "excludeEntryLine", "E":
      includeEntryLine = false
    of "sublinePattern", "s":
      subLinePattern = val
    of "lastSublineOnly", "l":
      showOnlyLastSublineMatched = true
    of "debug", "d":
      debug = true
    of "from", "f":
      fromRe = re(val)
    of "to", "t":
      toRe = re(val)
  of cmdEnd: assert(false) # cannot happen

if subLinePattern != nil:
  subLineSelector = Selector(invert: false, matcher: re(subLinePattern))
else: discard

if debug:
  echo "----------------------------------------------"
  echo "filename: ", filename
  echo "entry line pattern: ", entryLinePattern
  echo "max matches: ", maxMatches
  echo "subline pattern: ", subLinePattern
  echo "print line number: ", printLineNrs
  echo "----------------------------------------------"
else: discard

if printHelp:
   writeHelp()
else:
   let mainRe: Regex = if entryLinePattern == "": nil else: re(entryLinePattern)
   try:
      if isNil(filename): 
         let input = newFileStream(stdin)
         processLines(input, newFileStream(stdout), mainRe, fromRe, toRe, selectors, printLineNrs, maxMatches, sublineSelector, includeEntryLine, showOnlyLastSublineMatched)
      else: 
         let input = newFileStream(filename, fmRead)
         processLines(input, newFileStream(stdout), mainRe, fromRe, toRe, selectors, printLineNrs, maxMatches, sublineSelector, includeEntryLine, showOnlyLastSublineMatched)
   except IOError:
      quit(1)