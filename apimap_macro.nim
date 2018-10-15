from asynchttpserver import Request, HttpMethod
import tables
import macros
import templates
import typetraits

import autoindent

export tables.toTable

func methodStrFormat(methodType: string): string {.compileTime.} =
    case methodType:
    of "HEAD": "HttpHead"
    of "GET": "HttpGet"
    of "POST": "HttpPost"
    of "PUT": "HttpPut"
    of "DELETE": "HttpDelete"
    of "TRACE": "HttpTrace"
    of "OPTIONS": "HttpOptions"
    of "CONNECT": "HttpConnect"
    of "PATCH": "HttpPatch"
    else:
        warning "Unknown HTTP method: " & methodType
        "HttpGet"

# Intermediate types used in macro processing
type
    DefaultHandler* = proc (r: Request)
    IntmEndpoint = tuple[methodType: string, fn: string]
    IntmSubpath = object
        path: string
        endpoints: seq[IntmEndpoint]
        children: seq[IntmSubpath]

proc astToSubpath(body: NimNode, path = "/"): IntmSubpath {.compileTime.} =
    ## Convert the DSL block into an intermediate representation
    result = IntmSubpath(path: path, endpoints: @[], children: @[])
    for subpath in body:
        if subpath.len < 1: return
        if subpath[0].kind == nnkStrLit:
            result.children.add(astToSubpath(subpath[1], subpath[0].strVal))
        if subpath[0].kind == nnkIdent:
            let endpoint = (subpath[0].repr.methodStrFormat, subpath[1][0].repr)
            result.endpoints.add(endpoint)


proc apiResourceCodeGen(path: IntmSubpath, handlerType: string): string =
    ## Recursively generate code for each APIResource and all children
    tmpli nim"""
"$(path.path)": APIResource[$handlerType](
    $if path.endpoints.len > 0 {
        methods: @[
            $for endpt in path.endpoints {
            APIEndpoint[$handlerType](httpMethod: $(endpt.methodType), handler: $(endpt.fn)),
            }
        ],
    }
    $if path.children.len > 0 {
        children: {
            $for child in path.children {
                $(apiResourceCodeGen(child, handlerType))
            }
        }.toTable,
    }
),
    """

proc rootCodeGen(rootPath: IntmSubpath, handlerType: string): string =
    ## Generate code for creating the root APIMap
    tmpli nim"""
APIMap[$handlerType]({
    $(apiResourceCodeGen(rootPath, handlerType))
}.toTable)
    """

macro apiMap*(body: untyped): untyped =
    ##[
        converts a simple DSL into an APIMap object. Expects handlers in the
        form of the DefaultHandler type. An example of the DSL:

        var api = apiMap:
            "foo":
                GET: fooHandler
            "bar":
                POST: barHandler
                "baz":
                    GET: bazHandler
    ]##

    let codeResult = body.astToSubpath.rootCodeGen(DefaultHandler.name).autoindent
    result = parseStmt(codeResult)

macro apiMap*(handlerType: untyped, body: untyped): untyped =
    ##[
        converts a simple DSL into an APIMap object. Takes a handlerType
        parameter that is used for the type of the handler procedures. An
        example of the DSL:

        var api = apiMap(HandlerType):
            "foo":
                GET: fooHandler
            "bar":
                POST: barHandler
                "baz":
                    GET: bazHandler
    ]##

    var htype: string = DefaultHandler.name
    if handlerType.kind == nnkIdent:
        htype = handlerType.repr
    else:
        warning "Handler type: expected ident, got NimNodeKind = " & handlerType.kind.repr
    let codeResult = body.astToSubpath.rootCodeGen(htype).autoindent
    result = parseStmt(codeResult)
