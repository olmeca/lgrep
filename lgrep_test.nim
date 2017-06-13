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

import unittest, streams, re, strutils
import "lgrep_lib"


suite "general":
  
  setup:
    let input = """
    Time1 INFO: Thread1 - Method1: Event1
    Time2 INFO: Thread2 - Method1: Event2
    Time3 DEBUG: Thread1 - Method2: Event1
    Time4 ERROR: Thread3 - Method2: FirstException
      frame1
      frame2
    Caused by: SecondException
      frame3
    Caused by: ThirdException
      frame4
    Time5 INFO: Thread3 - Method2: Event2
    Time6 WARN: Thread3 - Method2: Exception1
      frame1
      frame2
    Caused by: Exception2
      frame3
    Time7 DEBUG: Thread2 - Method2: Event2
    """.unindent
    
    let main = re("Time")
    let output: StringStream = newStringStream()
    

  test "call without selectors returns input":
    
    processLines(newStringStream(input), output, nil, nil, nil, @[], false, 999'u, nil, true, false)
    check(output.data == input)

  test "inclusion selector returns empty resul if no match exists":
    
    let sel = newSelector("TRACE")
    let expected = ""

    processLines(newStringStream(input), output, main, nil, nil, @[sel], false, 999'u, nil, true, false)
    check(output.data == expected)

  test "selects the line matching the unique inclusion selector":
    
    let sel = newSelector("Time3")
    let expected = """
    Time3 DEBUG: Thread1 - Method2: Event1
    """.unindent
    
    processLines(newStringStream(input), output, main, nil, nil, @[sel], false, 999'u, nil, true, false)
    check(output.data == expected)

  test "line number is added to result if requested":
    
    let selector = newSelector("Time7")
    let expected = """
    17: Time7 DEBUG: Thread2 - Method2: Event2
    """.unindent
    
    processLines(newStringStream(input), output, main, nil, nil, @[selector], true, 999'u, nil, true, false)
    check(output.data == expected)

  test "selects multiple lines with inclusion selector":
    
    let selector = newSelector("DEBUG")
    let expected = """
    Time3 DEBUG: Thread1 - Method2: Event1
    Time7 DEBUG: Thread2 - Method2: Event2
    """.unindent

    processLines(newStringStream(input), output, main, nil, nil, @[selector], false, 999'u, nil, true, false)
    check(output.data == expected)

  test "selects intersection of multiple inclusion selectors":
    
    let sel1 = newSelector("DEBUG")
    let sel2 = newSelector("Event2")
    let expected = """
    Time7 DEBUG: Thread2 - Method2: Event2
    """.unindent

    processLines(newStringStream(input), output, main, nil, nil, @[sel1, sel2], false, 999'u, nil, true, false)
    check(output.data == expected)

  test "inclusion selector only matches main entry lines":
    
    let sel1 = newSelector("frame")
    let expected = ""

    processLines(newStringStream(input), output, main, nil, nil, @[sel1], false, 999'u, nil, true, false)
    check(output.data == expected)

  test "intersection of multiple exclusion selectors":
    
    let sel1 = Selector(invert: true, matcher: re("INFO"))
    let sel2 = Selector(invert: true, matcher: re("ERROR"))
    let expected = """
    Time3 DEBUG: Thread1 - Method2: Event1
    Time7 DEBUG: Thread2 - Method2: Event2
    """.unindent

  test "intersection of inclusion selector and exclusion selector":
    
    let sel1 = Selector(invert: false, matcher: re("INFO"))
    let sel2 = Selector(invert: true, matcher: re("Method1"))
    let expected = """
    Time5 INFO: Thread3 - Method2: Event2
    """.unindent

    processLines(newStringStream(input), output, main, nil, nil, @[sel1, sel2], false, 999'u, nil, true, false)
    check(output.data == expected)

  test "maximum matches limits result set with inclusion selector":
    
    let sel = newSelector("INFO")
    let expected = """
    Time1 INFO: Thread1 - Method1: Event1
    Time2 INFO: Thread2 - Method1: Event2
    """.unindent

    processLines(newStringStream(input), output, main, nil, nil, @[sel], false, 2'u, nil, true, false)
    check(output.data == expected)

  test "multiline entry is selected in its entirity":
    
    let sel = newSelector("ERROR")
    let expected = """
    Time4 ERROR: Thread3 - Method2: FirstException
      frame1
      frame2
    Caused by: SecondException
      frame3
    Caused by: ThirdException
      frame4
    """.unindent
    
    processLines(newStringStream(input), output, main, nil, nil, @[sel], false, 999'u, nil, true, false)
    check(output.data == expected)

  test "multiline entry can suppress main line":
    
    let sel = newSelector("ERROR")
    let expected = """
      frame1
      frame2
    Caused by: SecondException
      frame3
    Caused by: ThirdException
      frame4
    """.unindent
    
    processLines(newStringStream(input), output, main, nil, nil, @[sel], false, 999'u, nil, false, false)
    check(output.data == expected)

  test "multiline entry can make inclusion subselection":
    
    let sel = newSelector("ERROR")
    let sel1 = Selector(invert: false, matcher: re("Caused"))
    let expected = """
    Caused by: SecondException
    Caused by: ThirdException
    """.unindent
    
    processLines(newStringStream(input), output, main, nil, nil, @[sel], false, 999'u, sel1, false, false)
    check(output.data == expected)

  test "multiline entry can filter last subselection if multiple exist":
    
    let sel = newSelector("ERROR")
    let sel1 = Selector(invert: false, matcher: re("Caused"))
    let expected = """
    Caused by: ThirdException
    """.unindent
    
    processLines(newStringStream(input), output, main, nil, nil, @[sel], false, 999'u, sel1, false, true)
    check(output.data == expected)

  test "multiline entry can filter last subselection if one exists":
    
    let sel = newSelector("WARN")
    let sel1 = Selector(invert: false, matcher: re("Caused"))
    let expected = """
    Caused by: Exception2
    """.unindent
    
    processLines(newStringStream(input), output, main, nil, nil, @[sel], false, 999'u, sel1, false, true)
    check(output.data == expected)

  test "call with range selectors returns range when no subs":
    let expected = """
    Time3 DEBUG: Thread1 - Method2: Event1
    """.unindent
    
    processLines(newStringStream(input), output, main, re("Time3"), re("Time4"), @[], false, 999'u, nil, true, false)
    check(expected == output.data)

  test "call with range selectors returns range with sub":
    let expected = """
    Time6 WARN: Thread3 - Method2: Exception1
      frame1
      frame2
    Caused by: Exception2
      frame3
    """.unindent
    
    processLines(newStringStream(input), output, main, re("Time6"), re("Time7"), @[], false, 999'u, nil, true, false)
    check(expected == output.data)
