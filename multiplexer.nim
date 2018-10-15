from asynchttpserver import Request, HttpMethod
import tables
import strutils
import macros
import apimap_macro

export apimap_macro

# Defines the APIMap type, used for routing requests to specific handlers
type
    APIMap*[H] = Table[string, APIResource[H]]
    APIEndpoint*[H] = object
        httpMethod*: HttpMethod
        handler*: H
    APIResource*[H] = object
        children*: APIMap[H]
        methods*: seq[APIEndpoint[H]]

type
    NonExistentEndpointError = object of Exception

func findInEndpointSet[H](endpoints: seq[APIEndpoint[H]], httpMethod: HttpMethod): H =
    for endpt in endpoints:
        if endpt.httpMethod == httpMethod: return endpt.handler
    raise newException(NonExistentEndpointError, "No endpoint found with method " & httpMethod.repr)

func findHandler*[H](api: APIMap[H], path: string, httpMethod: HttpMethod): H =
    if path == "/" or path == "":
        return api["/"].methods.findInEndpointSet(httpMethod)
    var cur = api["/"].children
    var resourceResult: ApiResource[H]
    for pathSeg in path.split("/"):
        if pathSeg.len == 0: continue
        if cur.hasKey(pathSeg):
            resourceResult = cur[pathSeg]
            cur = cur[pathSeg].children
            continue
        else:
            raise newException(NonExistentEndpointError, "No path found for " & path)
    return resourceResult.methods.findInEndpointSet(httpMethod)
