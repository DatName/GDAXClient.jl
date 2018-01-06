module GDAXClient

using Requests
using Nettle
using DandelionWebSockets
using JSON

import Base: connect

abstract type AbstractGDAXEventsHandler <: DandelionWebSockets.WebSocketHandler end
abstract type AbstractGDAXOrder end

export getProducts, getServerTime, getProductOrderBook
export getProductTicker, getProductTrades, get24HourStats, getHistoricRates
export getCurrencies,  getPosition, getAccounts
export getAccountHistory, getAccountHolds
export placeOrder, cancelOrder, cancelAll, listOrders

export AbstractGDAXEventsHandler
export GDAXUser, GDAXLimitOrder, GDAXWebSocketClient
export connect, subscribe, unsubscribe, onMessage

struct GDAXUser
    rest_url::String
    key::String
    secret::String
    passphrase::String
end

struct GDAXLimitOrder <: AbstractGDAXOrder
    side::String #buy or sell
    product_id::String #A valid product id
    size::String #Amount of BTC to buy or sell
    price::String #Price per bitcoin
    client_oid::String #[optional] Order ID (UUID) selected by you to identify your order
    _type::String #[optional] limit, market, or stop (default is limit)
    stp::String #[optional] Self-trade prevention flag
                #dc 	Decrease and Cancel (default)
                #co 	Cancel oldest
                #cn 	Cancel newest
                #cb 	Cancel both
    time_in_force::String #[optional] GTC, GTT, IOC, or FOK (default is GTC)
    cancel_after::String #[optional min, hour, day (Requires time_in_force to be GTT)
    post_only::Bool #[optional] Post only flag (Invalid when time_in_force is IOC or FOK)
    function GDAXLimitOrder(side::String,
                            lots::String,
                            product_id::String,
                            price::String;
                            client_oid::String = "",
                            stp::String = "",
                            time_in_force::String = "",
                            cancel_after::String = "",
                            post_only::Bool = true)
        return new(side,
                    product_id,
                    lots,
                    price,
                    client_oid,
                    "limit",
                    stp,
                    time_in_force,
                    cancel_after,
                    post_only)
    end

end

include("rest.jl")
include("websocket.jl")
include("historical_data.jl")

end
