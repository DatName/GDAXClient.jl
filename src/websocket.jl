import DandelionWebSockets: wsconnect, on_text, on_binary
export on_text, on_binary

struct GDAXWebSocketClient{T <: AbstractGDAXMessageHandler} <: DandelionWebSockets.WebSocketHandler
    websocket_feed::String
    client::WSClient
    subscription::Dict{String, Any}
    events_handler::T

    function GDAXWebSocketClient(user::GDAXUser,
                                 subscription::Dict{String, Any},
                                 events_handler::T) where {T <: AbstractGDAXMessageHandler}

        if isregistered(user)
            merge!(subscription, getHeaders(user, "GET", "/users/self/verify", Dict()))
        end

        return new{T}(user.ws_feed, WSClient(ponger = DandelionWebSockets.Ponger(3.0; misses=90)), subscription, events_handler)
    end
end

function wsconnect(this::GDAXUser, subscription::Dict{String, Any}, events_handler::T) where {T <: AbstractGDAXMessageHandler}
    client = GDAXWebSocketClient(this, subscription, events_handler)
    connect(client)
    subscribe(client)
    return client
end

function connect(this::GDAXWebSocketClient)::GDAXWebSocketClient
    flag = DandelionWebSockets.wsconnect(this.client, URI(this.websocket_feed), this.events_handler)
    if !flag
        ws = this.websocket_feed
        throw(ErrorException("Unable to connect to $ws"))
    end

    return this
end

function subscribe(this::GDAXWebSocketClient)
    DandelionWebSockets.send_text(this.client, JSON.json(this.subscription))
end

function unsubscribe(this::GDAXWebSocketClient)
    unsubscription = this.subscription
    unsubscription["type"] = "unsubscribe"
    DandelionWebSockets.send_text(this.client, JSON.json(unsubscription))
end

function onWSMessage(this::AbstractGDAXMessageHandler, msg::Dict{String, X}) where {X <: Any}
    T = typeof(this)
    throw(ErrorException("Method `onMessage` is not implemented by $T"))
end

function on_text(this::T, str::String)::Void where {T <: AbstractGDAXMessageHandler}
    msg = try
        JSON.parse(str)
    catch exc
        Dict("type" => "parse_error",
             "text" => str,
             "exception" => exc)
    end

    onWSMessage(this, msg)
    return nothing
end

function on_binary(this::T, msg::Vector{UInt8}) where {T <: AbstractGDAXMessageHandler}
    @printf("[GDAXClient] Incoming binary data (this is unexpected)")
end

using .SlowOrderBook

struct GDAXOrderBooks <: AbstractGDAXMessageHandler
    books::Dict{String, OrderBook}
    condition::Condition
    function GDAXOrderBooks(products::Vector{String}, condition::Condition)
        b = Dict{String, OrderBook}()
        [b[x] = OrderBook() for x in products]
        return new(b, condition)
    end
end

import Base: getindex
export getindex

function getindex(this::GDAXOrderBooks, product_id::String)
    return this.books[product_id]
end

function onWSMessage(this::GDAXOrderBooks, msg::Dict{String, X}) where {X <: Any}
    if msg["type"] == "snapshot"
        book = this.books[msg["product_id"]]
        for asks in msg["asks"]
            price = parse(Float64, asks[1])
            lots = parse(Float64, asks[2])
            book["sell"][price] = lots
        end

        for bids in msg["bids"]
            price = parse(Float64, bids[1])
            lots = parse(Float64, bids[2])
            book["buy"][price] = lots
        end

        book.now.data = now(Dates.UTC)
    elseif msg["type"] == "l2update"
        book = this.books[msg["product_id"]]
        for item in msg["changes"]
            side = item[1]
            price = parse(Float64, item[2])
            lots = parse(Float64, item[3])

            book[side][price] = lots
        end

        book.now.data = DateTime(msg["time"], "yyyy-mm-ddTHH:MM:SS.sss\\Z")
        notify(this.condition)
    end
end
