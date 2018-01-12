# GDAXClient.jl - WIP

[GDAX](https://www.gdax.com/) API client written in Julia. Implemets REST API, WebSocket feed handling and FIX API
Websocket feed is handled via fork [DandelionWebSockets.jl](https://github.com/DatName/DandelionWebSockets.jl). NB: must use `release_1.0.0` brunch. FIX api is done through [FIX.jl](https://github.com/DatName/FIX.jl).

## Installation
```julia
julia> Pkg.clone("git@github.com:DatName/GDAXClient.git")
```

## [Authentication](https://docs.gdax.com/#authentication)
Authentication is handled via `GDAXUser` struct:
```julia
julia> using GDAXClient
julia> user = GDAXUser("https://api.gdax.com", "my_api_key", "my_secret_key", "my_passphrase")
```
If you don't have api keys (e.g. you have no account at GDAX), just pass empty keys and passphare: your access will be restricted to everything that does not require authentication.

## [REST API](https://docs.gdax.com/#api)
Most exported REST api  methods return `HttpCommon.Response` object. You can use `Requests.jl` to get what you need:
```julia
julia> resp = getProductOrderBook(user, "BTC-EUR")
julia> status = Requests.statuscode(resp)
julia> data = Requests.json(resp)
```
You can see full list of exported methods with
```julia
julia> names(GDAXClient)
```
### [Orders](https://docs.gdax.com/#orders)
?? `placeOrder()`, `cancelAll()`
GDAX is strict on order's price precision, so you should handle it yourself and pass value as string.

You can send an order via
```julia
julia> resp = placeOrder(user, order)
julia> Requests.statuscode(resp)
```
## [WebSocket feed](https://docs.gdax.com/#websocket-feed) client
WebSocket feed client is implemented through `GDAXWebSocketClient` struct.
```julia
julia> subscription = Dict("type" => "subscribe",
                            "product_ids" => ["BTC-EUR", "BTC-USD"],
                            "channels" => ["heartbeat", "level2", "full"])
julia> client = GDAXWebSocketClient(user, subscription, events_handler)
```
Where type of `events_handler` is a subtype of `AbstractMessageHandler`. All text messages from web socket feed are first parsed to `msg::Dict` via `JSON.json()` (as GDAX uses only jsons) and then passed to the following function
```julia
julia> onMessage(client.events_handler, msg)
```
This function must be implemented on users' side.

## [FIX API](https://docs.gdax.com/#fix-api)
```julia
julia> reg_user = GDAXUser("https://api.gdax.com", "wss://ws-feed.gdax.com", api_key, api_secret, passphrase)
julia> handler = TestEventsHandler(0)
julia> client = GDAXClient.fixconnect(reg_user, handler)
julia> m, mstr = placeOrder(client, "buy", "BTC-EUR", 0.0001001, 10000.0)
```
