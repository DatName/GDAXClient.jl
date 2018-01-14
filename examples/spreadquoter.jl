using FIX
using GDAXClient
using DataStructures

import FIX: onFIXMessage

#keep two quotes with fixed distance from average price.
#move them if price goes away further than `price_tolerance`

gadx_keys = JSON.parsefile(joinpath(homedir(),".gdax_keys"))
api_key = gadx_keys["Key"]
api_secret = gadx_keys["Secret"]
passphrase = gadx_keys["Passphrase"]

user = GDAXUser("https://api.gdax.com", "wss://ws-feed.gdax.com", api_key, api_secret, passphrase)
subscription = Dict("type" => "subscribe",
                    "product_ids" => ["BTC-EUR"],
                    "channels" => ["heartbeat", "level2", "full"])

bid_quote = FIXQuote("buy",  "BTC-EUR", 0.0001001, NaN, price_tolerance = 0.1)
ask_quote = FIXQuote("sell", "BTC-EUR", 0.0001001, NaN, price_tolerance = 0.1)

struct SpreadQuotes <: AbstractGDAXMessageHandler
    bid::FIXQuote
    ask::FIXQuote
end

function onFIXMessage(this::SpreadQuotes, msg::OrderedDict{Int64, String})
    onFIXMessage(this.bid, msg)
    onFIXMessage(this.ask, msg)
end

quoter = SpreadQuotes(bid_quote, ask_quote)

condition = Condition()
books     = GDAXOrderBooks(subscription["product_ids"], condition)

client = fixconnect(user, quoter)

#this is ugly
quoter.bid.client = client
quoter.ask.client = client

wsclient = wsconnect(user, subscription, books)

spread = NaN
exec_task  = @async begin
    while true
        wait(condition)
        avg_bid = getBidAveragePrice(books["BTC-EUR"], 0.5)
        avg_ask = getAskAveragePrice(books["BTC-EUR"], 0.5)

        mid_price = (avg_bid + avg_ask) / 2.0
        quoter.bid.price = mid_price - spread
        quoter.ask.price = mid_price + spread

        GDAXClient.maintain(quoter.bid)
        GDAXClient.maintain(quoter.ask)
    end
    println("exec task exiting")
end

#now adjust spread and tolerances as you wish
spread = 100.0
quoter.bid.price_tolerance = 10.0
quoter.ask.price_tolerance = 10.0
