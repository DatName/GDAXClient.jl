__precompile__(false)

module GDAXClient

using Requests
using Nettle
using DandelionWebSockets
using JSON
using FIX
using MbedTLS

import Base: connect

abstract type AbstractGDAXMessageHandler <: FIX.AbstractMessageHandler end

export getProducts, getServerTime, getProductOrderBook
export getProductTicker, getProductTrades, get24HourStats, getHistoricRates
export getCurrencies,  getPosition, getAccounts
export getAccountHistory, getAccountHolds
export placeOrder, cancelOrder, cancelAll, listOrders

export GDAXUser, GDAXWebSocketClient
export connect, subscribe, unsubscribe, onMessage
export AbstractGDAXMessageHandler

struct GDAXUser
    rest_url::String
    ws_feed::String
    key::String
    secret::String
    passphrase::String
end

isregistered(this::GDAXUser) = (!isempty(this.key) && !isempty(this.secret) && !isempty(this.passphrase))

include("rest.jl")
include("websocket.jl")
include("fix.jl")
include("historical_data.jl")

end
