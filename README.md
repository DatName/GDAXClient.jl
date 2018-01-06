# GDAXClient.jl

An [GDAX](https://www.gdax.com/) API client written in Julia. Implemets REST API and WebSocket feed handling (via [DandelionWebSockets.jl](https://github.com/dandeliondeathray/DandelionWebSockets.jl))

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
Currently only limit order type is implemeted via `GDAXLimitOrder` struct.
```julia
julia> order = GDAXLimitOrder("buy", "0.0001", "BTC-EUR", "14000.0", time_in_force = "GTC")
```
GDAX is strict on order's price precision, so you should handle it yourself and pass value as string.

You can send an order via
```julia
julia> resp = placeOrder(user, order)
julia> Requests.statuscode(resp)
```
## [WebSocket feed](https://docs.gdax.com/#websocket-feed) client
WebSocket feed client is implemented through `GDAXWebSocketClient` struct.
```julia
julia> ws_feed = "wss://ws-feed.gdax.com"
julia> subscription = Dict("type" => "subscribe",
                            "product_ids" => ["BTC-EUR", "BTC-USD"],
                            "channels" => ["heartbeat", "level2", "full"])
julia> client = GDAXWebSocketClient(ws_feed, subscription, events_handler, user = user)
```
Where type of `events_handler` is a subtype of `AbstractGDAXEventsHandler`. All text messages from web socket feed are first parsed to `msg::Dict` via `JSON.json()` (as GDAX uses only jsons) and then passed to the following function
```julia
julia> onMessage(client.events_handler, msg)
```
This function must be implemented on users' side.
