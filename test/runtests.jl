using GDAXClient
using Base.Test

user = GDAXUser("https://api.gdax.com", "", "", "")

@testset "Public" begin
    @test Requests.statuscode(getProducts(user)) == 200
    @test Requests.statuscode(getServerTime(user)) == 200
    @test Requests.statuscode(getProductOrderBook(user, "BTC-EUR")) == 200
    @test Requests.statuscode(getProductTicker(user, "BTC-EUR")) == 200
    @test Requests.statuscode(getProductTrades(user, "BTC-EUR")) == 200

    resp = getHistoricRates(user, "BTC-USD", DateTime(2018, 1, 4), DateTime(2018, 1, 4, 0, 2, 0), 60)
    Requests.json(resp)
    @test Requests.statuscode(resp) == 200
    @test length(Requests.json(resp)) == 2

    resp = get24HourStats(user, "BTC-USD")
    @test Requests.statuscode(resp) == 200
    @test !isempty(Requests.json(resp))

    @test Requests.statuscode(getCurrencies(user)) == 200
end

@testset "Orders" begin
    order = GDAXLimitOrder("buy", "0.0001", "BTC-EUR", "14000.0")
    msg = GDAXClient.marshal(order)
    @test msg["product_id"] == "BTC-EUR"
    @test msg["size"] == "0.0001"
    @test msg["side"] == "buy"
    @test msg["price"] == "14000.0"
    @test msg["post_only"] == true
    @test msg["type"] == "limit"
    @test length(msg) == 6

    @test Requests.statuscode(listOrders(user)) == 401
    @test Requests.statuscode(placeOrder(user, order)) == 401
    @test Requests.statuscode(cancelOrder(user, string(Base.Random.uuid4()))) == 401
end

mutable struct TestEventsHandler <: AbstractGDAXEventsHandler
    message_counter::Int64
end

import GDAXClient: onMessage

function onMessage(this::TestEventsHandler, msg::Dict{String, X})::Void where {X <: Any}
    this.message_counter += 1
    return nothing
end

@testset "Websocket" begin
    ws_feed = "wss://ws-feed.gdax.com"

    subscription = Dict("type" => "subscribe",
                        "product_ids" => ["BTC-EUR", "BTC-USD"],
                        "channels" => ["heartbeat", "level2", "full"])

    h = GDAXWebSocketClient(ws_feed,
                            subscription,
                            TestEventsHandler(1),
                            user = user)
    connect(h)
    subscribe(h)
    sleep(5)
    @test h.events_handler.message_counter > 0
    unsubscribe(h)
    sleep(5) #make sure to unsubscribe, though it might fail
    n = h.events_handler.message_counter
    sleep(5) #wait for new message that may arrive
    # test that there is no new messages
    @test n == h.events_handler.message_counter
end
