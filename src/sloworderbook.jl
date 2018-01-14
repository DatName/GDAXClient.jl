module SlowOrderBook

import Base: getindex, setindex!

export OrderBook
export getindex, setindex
export getAveragePrice, getBidAveragePrice, getAskAveragePrice
export getSpread

struct OrderBookSide
    data::Dict{Float64, Float64}
    function OrderBookSide()
        return new(Dict{Float64, Float64}())
    end
end

mutable struct Container{T}
    data::T
end

struct OrderBook
    bids::OrderBookSide
    asks::OrderBookSide
    now::Container{DateTime}
    function OrderBook()
        return new(OrderBookSide(),
                OrderBookSide(),
                Container(DateTime()))
    end
end

function getindex(this::OrderBook, side::String)::OrderBookSide
    if side == "sell"
        return this.asks
    end

    if side == "buy"
        return this.bids
    end

    throw(ErrorException("Unknown book side: $side"))
end

function setindex!(this::OrderBookSide, lots::Float64, price::Float64)::Void
    if lots ≈ 0.0
        delete!(this.data, price)
    else
        this.data[price] = lots
    end

    return nothing
end

function bestBid(this::OrderBook)::Float64
    return max_price(this.bids)
end

function bestAsk(this::OrderBook)::Float64
    return min_price(this.asks)
end

function max_price(this::OrderBookSide)::Float64
    if isempty(this.data)
        return NaN
    end

    return maximum(collect(keys(this.data)))
end

function min_price(this::OrderBookSide)::Float64
    if isempty(this.data)
        return NaN
    end

    return minimum(collect(keys(this.data)))
end

function getAveragePrice(this::OrderBookSide, sz::Float64, rev::Bool)::Float64
    prices = collect(keys(this.data))
    sizes  = collect(values(this.data))
    jperm = sortperm(prices, rev = rev)

    prices = prices[jperm]
    sizes = sizes[jperm]

    avgsz = 0.0
    cumsz = 0.0
    for j = 1 : length(prices)
        this_size = min(sizes[j], sz - cumsz)
        cumsz += this_size
        avgsz += prices[j] * this_size
        if cumsz >= sz
            break
        end
    end

    if cumsz ≈ 0.0
        return NaN
    end

    return avgsz / cumsz
end

getSpread(this::OrderBook) = bestAsk(this) - bestBid(this)
getSpread(this::OrderBook, sz::Float64) = getAskAveragePrice(this, sz) - getBidAveragePrice(this, sz)

function getBidAveragePrice(this::OrderBook, sz::Float64)::Float64
    return getAveragePrice(this.bids, sz, true)
end

function getAskAveragePrice(this::OrderBook, sz::Float64)::Float64
    return getAveragePrice(this.asks, sz, false)
end

getAveragePrice(this::OrderBook, sz::Float64) = (getBidAveragePrice(this, sz) + getAskAveragePrice(this, sz)) / 2.0

end
