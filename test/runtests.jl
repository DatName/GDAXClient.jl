using GDAXClient
using Base.Test

user = GDAXUser("https://api.gdax.com", "wss://ws-feed.gdax.com", "", "", "")

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
    @test Requests.statuscode(listOrders(user)) == 401
    @test Requests.statuscode(placeOrder(user, "buy", "BTC-USD", 0.00010001, 12000.0)) == 401
    @test Requests.statuscode(cancelOrder(user, string(Base.Random.uuid4()))) == 401
end

mutable struct TestEventsHandler <: GDAXClient.AbstractGDAXMessageHandler
    message_counter::Int64
end

import GDAXClient: onMessage

function onMessage(this::TestEventsHandler, msg::Dict{String, Any})::Void
    this.message_counter += 1
    return nothing
end

@testset "Websocket" begin
    subscription = Dict("type" => "subscribe",
                        "product_ids" => ["BTC-EUR", "BTC-USD"],
                        "channels" => ["heartbeat", "level2", "full"])

    client = GDAXWebSocketClient(user,
                            subscription,
                            TestEventsHandler(0))

    connect(client)
    subscribe(client)
    sleep(25)
    @test client.events_handler.message_counter > 0
    unsubscribe(client)
    sleep(5) #make sure to unsubscribe, though it might fail
    n = client.events_handler.message_counter
    sleep(15) #wait for new message that may arrive
    # test that there is no new messages
    @test n == client.events_handler.message_counter
end

gadx_keys = JSON.parsefile(joinpath(homedir(),".gdax_keys"))
api_key = gadx_keys["Key"]
api_secret = gadx_keys["Secret"]
passphrase = gadx_keys["Passphrase"]

reg_user = GDAXUser("https://api.gdax.com", "wss://ws-feed.gdax.com", api_key, api_secret, passphrase)

using FIX
import FIX: onFIXMessage
using DataStructures
function onFIXMessage(this::TestEventsHandler, msg::OrderedDict{Int64, String})
    this.message_counter += 1
    return nothing
end
handler = TestEventsHandler(0)

client = GDAXClient.fixconnect(reg_user, handler)
placeOrder(client, "buy", "BTC-EUR", 0.0001001, 10000.0)
