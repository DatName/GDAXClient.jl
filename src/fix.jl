using FIX
using DataStructures

import FIX: onFIXMessage

export logout
export onFIXMessage

function fixconnect(user::GDAXUser, handler::H) where {H <: AbstractGDAXMessageHandler}
    client = FIXClient(MbedTLS.connect("127.0.01", 4198),
                        handler,
                        Dict(8=>"FIX.4.2",
                             49=>user.key,
                             56=>"Coinbase"),
                             RateLimit(50, Dates.Second(1)))
    start(client)
    send_message(client, login_message(user.key, user.secret, user.passphrase))
    return client
end

function logout(client::FIXClient{TCPSocket, H}) where {H <: AbstractGDAXMessageHandler}
    send_message(client, logout_message())
end

function login_message(api_key::String, api_secret::String, passphrase::String)::Dict{Int64, String}
    t = Dates.format(now(Dates.UTC), "yyyy-mm-ddTHH:MM:SS.sss")
    seq_num = "1"
    message   = join([t , "A" , seq_num, api_key, "Coinbase", passphrase], Char(1))
    hmac_key  = base64decode(api_secret)
    h = HMACState("sha256", hmac_key)
    Nettle.update!(h, message)
    signature = base64encode(Nettle.digest!(h))

    return Dict{Int64, String}(35  => "A",
                             98  => "0",
                            108  => "30",
                            52 => t,
                            554  => passphrase,
                            96   => signature,
                            8013 => "Y" )
end

function logout_message()
    return Dict{Int64, String}(35=>"5")
end

function placeOrder(this::FIXClient{TCPSocket, H},
                        side::String,
                        instrument::String,
                        lots::Float64,
                        price::Float64) where {H <: AbstractGDAXMessageHandler}
    id = string(Base.Random.uuid4())
    ord = Dict{Int64, String}(35=>"D",
                        21 => "1",
                        11 => id,
                        55 => instrument,
                        54 => side,
                        44 => string(signif(price, 6)),
                        38 => string(signif(lots, 8)),
                        40 => "2",
                        59 => "1",
                        7928 => "B")
    send_message(this, ord)
end

function cancelAll(this::FIXClient{TCPSocket, H}) where {H <: AbstractGDAXMessageHandler}
    for order in FIX.getOpenOrders(this)
        c = Dict{Int64, String}()
        c[11] = string(Base.Random.uuid4())
        c[37] = order[37]
        c[41] = order[11]
        c[55] = order[55]
        c[35] = "F"
        send_message(this, c)
    end
end

mutable struct FIXOrderChain
    cl::Pair{String, Dict{Int64, String}}
    cl_ex::Pair{String, Dict{Int64, String}}
    rm::String
    rm_ex::Bool
    rejected::Bool
    function FIXOrderChain()
        return new(Pair("", Dict{Int64, String}()),
                    Pair("", Dict{Int64, String}()),
                    "",
                    false,
                    false)
    end
end

mutable struct FIXQuote <: AbstractGDAXMessageHandler
    side::String
    instrument::String
    lots::Float64
    price::Float64
    lots_tolerance::Float64
    price_tolerance::Float64
    chains::OrderedDict{String, FIXOrderChain}
    storage::Vector{FIXOrderChain}
    client::FIXClient
    m_lock::ReentrantLock
    function FIXQuote(side::String,
                    instrument::String,
                    lots::Float64,
                    price::Float64;
                    lots_tolerance::Float64 = 1e-4+1e-6,
                    price_tolerance::Float64 = 1.0)
        this = new()
        this.side = side
        this.instrument = instrument
        this.lots = lots
        this.price = price
        this.lots_tolerance = lots_tolerance
        this.price_tolerance = price_tolerance
        this.chains = OrderedDict{String, FIXOrderChain}()
        this.storage = FIXOrderChain[]
        this.m_lock = ReentrantLock()
        return this
    end
end

function onWSMessage(this::FIXQuote, msg::Dict{String, Any})
    maintain(this)
end

function onFIXMessage(this::FIXQuote, msg::OrderedDict{Int64, String})
    msg_type = msg[35]
    if msg_type == "8"
        exec_type = msg[150]
        for chain in values(this.chains)
            if exec_type == "0" #new order single
                if msg[11] == chain.cl.first
                    chain.cl_ex = Pair(msg[37], msg)
                end
            elseif exec_type == "1" #fill
                if msg[37] == chain.cl_ex.first
                    filled_size = parse(Float64, msg[32])
                    got_size = parse(Float64, chain.cl_ex.second[38])
                    chain.cl_ex.second[38] = string(signif(got_size - filled_size, 8))
                end
            elseif exec_type == "3" #reject
                if msg[37] == chain.cl_ex.first #newOrderSingle reject
                    chain.rejected = true
                end
            elseif exec_type == "4" #cancel
                if msg[37] == chain.cl_ex.first
                    chain.rm_ex = true
                end
            elseif exec_type == "9" #order cancel reject
                cancel_request_client_id = msg[11]
                for (id, chain) in this.chains
                    if chain.rm == cancel_request_client_id
                        chain.rm = ""
                        chain.rm_ex = false
                    end
                end
            end
        end
    end
    maintain(this)
end

function maintain(this::FIXQuote)
    lock(this.m_lock)
    for (id, chain) in this.chains
        if chain.rm_ex || chain.rejected
            push!(this.storage, chain)
            delete!(this.chains, id)
        end
    end

    if isempty(this.chains)
        this.lots > 0.0 && !isnan(this.price) && addNewChain(this)
    else
        for (id, chain) in this.chains
            if isempty(chain.cl_ex.first)
                continue
            end
            if !isempty(chain.rm)
                continue
            end
            cur_price = parse(Float64, chain.cl_ex.second[44])
            cur_lots  = parse(Float64, chain.cl_ex.second[38])

            price_ok = abs(cur_price - this.price) < this.price_tolerance
            lots_ok = abs(cur_lots - this.lots) < this.lots_tolerance

            if !price_ok || !lots_ok
                closeChain(this, chain)
                if this.lots > 0.0 && !isnan(this.price)
                    addNewChain(this)
                    break #maintain(this)
                end
            end
        end
    end
    unlock(this.m_lock)
end

function getPrice(this::FIXOrderChain)
    if isempty(this.cl_ex.first)
        return NaN
    end
    return parse(Float64, this.cl_ex.second[44])
end

function getLots(this::FIXOrderChain)
    if isempty(this.cl_ex.first)
        return NaN
    end
    return parse(Float64, this.cl_ex.second[38])
end

function closeChain(this::FIXQuote, chain::FIXOrderChain)
    client = this.client
    c = Dict{Int64, String}()
    c[11] = string(Base.Random.uuid4())
    c[37] = chain.cl_ex.first
    c[41] = chain.cl.first
    c[55] = this.instrument
    c[35] = "F"
    (msg, msg_str) = send_message(client, c)
    chain.rm = msg[11]
    return nothing
end

function addNewChain(this::FIXQuote)
    numleft = FIX.numMsgsLeftToSend(this.client)
    if numleft < 10
        @printf("[%ls][FIXQuote][RateLimit]: blocked. %2.2f msg per second\n", now(), this.client.m_messages.outgoing.ratelimit())
        return nothing
    end
    (msg, msg_str) = placeOrder(this.client, this.side, this.instrument, this.lots, this.price)
    id = msg[11]
    this.chains[id] = FIXOrderChain()
    this.chains[id].cl = Pair(id, msg)
    return nothing
end
