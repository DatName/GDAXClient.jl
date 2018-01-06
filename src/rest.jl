function getHeaders(this::GDAXUser,
                    method::String,
                    request_path::String,
                    body::Dict)::Dict{String, String}
    timestamp = Int64(round(Dates.datetime2unix(now(Dates.UTC))))
    body_str  = isempty(body) ? "" : JSON.json(body)
    prehash_signature = string(timestamp, uppercase(method), request_path, body_str)
    h = HMACState("sha256", base64decode(this.secret))
    Nettle.update!(h, prehash_signature)
    signature = base64encode(digest!(h))

    return Dict("CB-ACCESS-KEY" => this.key,
                    "CB-ACCESS-SIGN" => signature,
                    "CB-ACCESS-TIMESTAMP" => string(timestamp),
                    "CB-ACCESS-PASSPHRASE" => this.passphrase,
                    "Content-Type" => "application/json")
end

function send_request(this::GDAXUser,
                        method::String, request_path::String; query = Dict(), json = Dict())

    query_str = Requests.format_query_str(query)
    query_str = "?" * query_str
    while !isempty(query_str) && last(query_str) == '?'
        query_str = chop(query_str)
    end

    handle = eval(parse("Requests." * lowercase(method)))

    return handle(this.rest_url * request_path,
                 query = query,
                 json = isempty(json) ? nothing : json,
                 headers = getHeaders(this, method, request_path * query_str, json))
end

getProducts(this::GDAXUser) = send_request(this, "get", "/products")
getServerTime(this::GDAXUser) = send_request(this, "get", "/time")
getProductOrderBook(this::GDAXUser, product_id::String; level::Int64 = 2) = send_request(this, "get", "/products/" * product_id * "/book", query = Dict("level" => level))
getProductTicker(this::GDAXUser, product_id::String) = send_request(this, "get", "/products/" * product_id * "/ticker")
getProductTrades(this::GDAXUser, product_id::String) = send_request(this, "get", "/products/" * product_id * "/trades")
get24HourStats(this::GDAXUser, product_id::String) = send_request(this, "get", "/products/" * product_id * "/stats")
getCurrencies(this::GDAXUser) = send_request(this, "get", "/currencies")
getPosition(this::GDAXUser) = send_request(this, "get", "/position")
getAccounts(this::GDAXUser) = send_request(this, "get", "/accounts")
getAccountHistory(this::GDAXUser, account_id::String) = send_request(this, "get", "/accounts/" * account_id * "/ledger")
getAccountHolds(this::GDAXUser, account_id::String) = send_request(this, "get", "/accounts/" * account_id * "/holds")

"""
Response Items

Each bucket is an array of the following information:

    * time bucket start time
    * low lowest price during the bucket interval
    * high highest price during the bucket interval
    * open opening price (first trade) in the bucket interval
    * close closing price (last trade) in the bucket interval
    * volume volume of trading activity during the bucket interval
"""
function getHistoricRates(this::GDAXUser,
                            product_id::String,
                            from::DateTime,
                            to::DateTime,
                            granularity::Int64)
    send_request(this, "get", "/products/" * product_id * "/candles", query = Dict("start" => from,
                                                                  "end" => to,
                                                                  "granularity" => granularity))
end

"""
acc_type    fill or account
start_date 	Starting date for the report (inclusive)
end_date 	Ending date for the report (inclusive)
product_id 	ID of the product to generate a fills report for. E.g. BTC-USD. Required if type is fills
account_id 	ID of the account to generate an account report for. Required if type is account
format 	pdf or csv (defualt is pdf)
email 	Email address to send the report to (optional)
"""
function getReport(this::GDAXUser,
                    report_type::String,
                    start_date::DateTime,
                    end_date::DateTime,
                    product_id::String,
                    account_id::String,
                    format::String,
                    email::String)

    request_path = "/reports"
    data = Dict("type" => report_type,
                "start_date" => Dates.format(start_date, "yyyy-mm-ddTHH:MM:SS\\Z"),
                "end_date" => Dates.format(end_date, "yyyy-mm-ddTHH:MM:SS\\Z"),
                "product_id" => product_id,
                "account_id" => account_id,
                "format" => format,
                "email" => email)

    return send_request(this, "post", request_path, json = data)
end

function marshal(this::GDAXLimitOrder)::Dict{String, Any}
    out = Dict{String, Any}("side" => this.side,
                            "product_id" => this.product_id,
                            "price" => this.price,
                            "size" => this.size)

    !isempty(this.stp) && (out["stp"] => this.stp)
    !isempty(this.time_in_force) && (out["time_in_force"] = this.time_in_force)
    !isempty(this.cancel_after) && (out["cancel_after"] = this.cancel_after)
    !isempty(this.post_only) && (out["post_only"] = this.post_only)
    !isempty(this.client_oid) && (out["client_oid"] = this.client_oid)
    !isempty(this._type) && (out["type"] = this._type)
    !isempty(this.stp) && (out["stp"] = this.stp)

    return out
end

function placeOrder(this::GDAXUser, order::T) where {T <: AbstractGDAXOrder}
    send_request(this, "post", "/orders", json = marshal(order))
end

function cancelOrder(this::GDAXUser, order_id::String)
    send_request(this, "delete", "/orders/" * order_id)
end

function cancelAll(this::GDAXUser)
    send_request(this, "delete", "/orders")
end

function listOrders(this::GDAXUser; product_id::String = "", status::String = "all")
    query = Dict("status" => status)
    !isempty(product_id) && (query["product_id"] = product_id)
    return send_request(this, "get", "/orders", query = query)
end
