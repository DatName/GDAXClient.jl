import DandelionWebSockets: on_text, on_binary
export on_text, on_binary

struct GDAXWebSocketClient{T <: AbstractGDAXEventsHandler} <: DandelionWebSockets.WebSocketHandler
    websocket_feed::String
    client::WSClient
    subscription::Dict{String, Any}
    events_handler::T

    function GDAXWebSocketClient(websocket_feed::String,
                                 subscription::Dict{String, Any},
                                 events_handler::T;
                                 user::Union{Void, GDAXUser} = nothing) where {T <: AbstractGDAXEventsHandler}

        client = WSClient()
        if user != nothing
            merge!(subscription, getHeaders(user, "GET", "/users/self/verify", Dict()))
        end

        return new{T}(websocket_feed, client, subscription, events_handler)
    end
end

function connect(this::GDAXWebSocketClient)::GDAXWebSocketClient
    flag = wsconnect(this.client, URI(this.websocket_feed), this.events_handler)
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

function onMessage(this::AbstractGDAXEventsHandler, msg::Dict{String, X}) where {X <: Any}
    T = typeof(this)
    throw(ErrorException("Method `onMessage` is not implemented by $T"))
end

function on_text(this::T, str::String)::Void where {T <: AbstractGDAXEventsHandler}

    msg = try
        JSON.parse(str)
    catch exc
        Dict("type" => "parse_error",
             "text" => str,
             "exception" => exc)
    end

    onMessage(this, msg)
    return nothing
end

function on_binary(this::T, msg::Vector{UInt8}) where {T <: AbstractGDAXEventsHandler}
    @printf("[GDAXClient] Incoming binary data (this is unexpected)")
end
