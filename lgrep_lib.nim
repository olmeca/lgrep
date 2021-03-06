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

import re, streams, strutils
import posix

type
    RangeState = enum
        rsBefore, rsWithin, rsAfter

type
    Selector* = ref object
        invert*: bool
        matcher*: Regex
        pattern*: string

proc newSelector*(aPattern: string, mirror = false): Selector =
    return Selector(invert: mirror, matcher: re(aPattern), pattern: aPattern)

proc matches(line: string, regex: Regex): bool =
    result = find(line, regex) > -1

proc printLine(line: string, nr: uint, includeNr: bool): string =
    if includeNr:
        result = format("$1: $2", nr, line)
    else:
        result = line
        
proc matchSelector*(line: string, selector: Selector): bool =
    result = selector.invert xor matches(line, selector.matcher)

proc matchAll*(line: string, selectors: seq[Selector]): bool =
    result = true
    for selector in selectors:
        if not matchSelector(line, selector):
            result = false

proc processLines*(input: Stream, output: Stream, mainRe: Regex, startRe: Regex, endRe: Regex, selectors: seq[Selector], includeLineNr: bool, maxMatches: uint, subSelector: Selector, includeMain: bool, printOnlyLastSub: bool) =

    var nMatches: uint = maxMatches + 1
    var line: string = ""
    var isMainLine: bool = mainRe == nil
    var isPrevMainLine = false
    var isMatchingRange = false
    var lineNr: uint
    var lineToPrint: string = ""
    var rangePos: RangeState = if isNil(startRe): rsWithin else: rsBefore

    while nMatches > 0'u and input.readLine(line):
        lineNr = lineNr + 1
        isPrevMainLine = isMainLine
        isMainLine = mainRe == nil or matches(line, mainRe)
        if isMainLine:
            if rangePos == rsBefore:
                rangePos = if matches(line, startRe): rsWithin else: rsBefore
            elif rangePos == rsWithin and not isNil(endRe):
                rangePos = if matches(line, endRe): rsAfter else: rsWithin
            else: discard
            if lineToPrint != "":
                output.writeLine(lineToPrint)
                onSignal(SIGPIPE):
                    return
                lineToPrint = ""
            else: discard
            if rangePos == rsWithin:
                isMatchingRange = matchAll(line, selectors)
                # if we have a matching main line
                if isMatchingRange:
                    nMatches = nMatches - 1
                    if includeMain and nMatches > 0'u:
                        output.writeLine(printLine(line, lineNr, includeLineNr))
                        onSignal(SIGPIPE):
                            return
                    else: discard
                else: discard
            else: discard
        else:
            if isMatchingRange and rangePos == rsWithin:
                if subSelector == nil or matchSelector(line, subSelector):
                    let printOut = printLine(line, lineNr, includeLineNr)
                    if printOnlyLastSub:
                        lineToPrint = printOut
                    else:
                        output.writeLine(printOut)
                        onSignal(SIGPIPE):
                            return
                else: discard
            else: discard
    if lineToPrint != "":
        output.writeLine(lineToPrint)
        onSignal(SIGPIPE):
            return
        lineToPrint = ""
    else: discard
