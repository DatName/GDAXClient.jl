using FIX

function fixconnect(user::GDAXUser, events_handler::T) where {T <: AbstractGDAXMessageHandler}
    client = connect(user.key, events_handler)
    start(client)
    sleep(1.0)

    send_message(client, login_message(user.key, user.secret, user.passphrase))
    return client
end

function logout(client::FIXClient{TCPSocket, T}) where {T <: AbstractGDAXMessageHandler}
    send_message(client, logout_message())
end

function connect(api_key::String, handler::T)::FIXClient{TCPSocket, T} where {T <: AbstractGDAXMessageHandler}
    #TODO: make sure stunnel is up
    return FIXClient(MbedTLS.connect("127.0.01", 4198),
                    handler,
                    Dict(8=>"FIX.4.2",
                         49=>api_key,
                         56=>"Coinbase"))
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

function placeOrder(this::FIXClient{TCPSocket, T},
                        side::String,
                        instrument::String,
                        lots::Float64,
                        price::Float64) where {T <: AbstractGDAXMessageHandler}
    client_order_id = string(Base.Random.uuid4())
    ord = Dict{Int64, String}(35=>"D",
                        21 => "1",
                        11 => client_order_id,
                        55 => instrument,
                        54 => side,
                        44 => string(signif(price, 6)),
                        38 => string(signif(lots, 8)),
                        40 => "2",
                        59 => "1",
                        7928 => "B")
    send_message(this, ord)
end

function cancelAll(this::FIXClient{TCPSocket, T}) where {T <: AbstractGDAXMessageHandler}
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
