import strutils

const defaultIndent* = {'(', '[', '{'}
const defaultDedent* = {')', ']', '}'}

func autoindent*(body: string, indentChars = defaultIndent, dedentChars = defaultDedent): string =
    ## Naively indent a code block. Does not attempt to preserve existing whitespace
    ## or to manage blocks that should be indented with ``:``.
    result = ""
    var indent = 0
    for line in body.splitLines:
        let flatLine = line.strip.indent(indent, padding = spaces(4))
        result &= "\n" & flatLine
        for c in flatLine:
            if c in indentChars: indent.inc
            if c in dedentChars: indent.dec
