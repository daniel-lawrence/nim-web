# nim-web

This is a work in progress. The only useful part of this is a macro that adds a small DSL for defining REST APIs. An example:

```nim
var myApi = apiMap:
    "index":
        GET: indexHandler
```

This will automatically expand to:

```nim
var myApi = APIMap({
    "/": APIResource(
        children: {
            "index": APIResource(
                methods: @[
                    APIEndpoint(httpMethod: HttpGet, handler: indexHandler),
                ],
            ),
        }.toTable,
    ),
}.toTable)
```
