# nim-web

This is a work in progress. The only useful part of this is a macro that adds a small DSL for defining REST APIs. An example:

```nim
var myApi = apiMap:
    "index":
        GET: indexHandler
```

This will automatically expand to:

```nim
var myApi = APIMap[DefaultHandler]({
    "/": APIResource[DefaultHandler](
        children: {
            "index": APIResource[DefaultHandler](
                methods: @[
                    APIEndpoint[DefaultHandler](httpMethod: HttpGet, handler: indexHandler),
                ],
            ),
        }.toTable,
    ),
}.toTable)
```

By default, handlers procedures must have the `DefaultHandler` type. To use other types of handlers, a custom handler type may be passed as the first argument to the macro. For example:

```nim
type MyHandlerType = proc(jsonStr: string): string
var myApi = apiMap(MyHandlerType):
    "index":
        GET: indexHandler
```

This will allow `indexHandler` to be any procedure that takes a string and returns another string.
