from asynchttpserver import Request, HttpMethod
import tables
import macros
import templates
import autoindent

export tables.toTable

func methodStrFormat(methodType: string): string =
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
    else: "HttpGet"

# Defines types meant for use by consumers of the path produced by the apiMap macro
type
    BasicHandler* = proc (req: Request)
    APIMap* = Table[string, APIResource]
    APIEndpoint* = object
        httpMethod: HttpMethod
        handler: BasicHandler
    APIResource* = object
        children: APIMap
        methods: seq[APIEndpoint]

# Defines intermediate types, used in macro processing
type
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


proc apiResourceCodeGen(path: IntmSubpath): string =
    ## Recursively generate code for each APIResource and all children
    tmpli nim"""
"$(path.path)": APIResource(
    $if path.endpoints.len > 0 {
        methods: @[
            $for endpt in path.endpoints {
            APIEndpoint(httpMethod: $(endpt.methodType), handler: $(endpt.fn)),
            }
        ],
    }
    $if path.children.len > 0 {
        children: {
            $for child in path.children {
                $(apiResourceCodeGen(child))
            }
        }.toTable,
    }
),
    """

proc rootCodeGen(rootPath: IntmSubpath): string =
    ## Generate code for creating the root APIMap
    tmpli nim"""
APIMap({
    $(apiResourceCodeGen(rootPath))
}.toTable)
    """

macro apiMap*(body: untyped): untyped =
    ##[
        converts a simple DSL into an APIMap object. An example of the DSL:

        var api = apiMap:
            "foo":
                GET: fooHandler
            "bar":
                POST: barHandler
                "baz":
                    GET: bazHandler
    ]##
    let codeResult = body.astToSubpath.rootCodeGen.autoindent
    result = parseStmt(codeResult)
