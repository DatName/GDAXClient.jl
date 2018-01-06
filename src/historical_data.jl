"""
    GDAX has a restriction on the size of a bunch of data that is return by getHistoricRates() call.
    This function returns vector of `buckets` safely with multiple requests
    See https://docs.gdax.com/#get-historic-rates
"""
function safely_load_historical_data( product_id::String,
                                from::DateTime,
                                until::DateTime,
                                granularity::Int64;
                                verbose::Bool = true)::Vector{Dict{String, Any}}

   num_fails_max = 10
   num_fails = 0
   storage = Vector{Any}(0)
   user = GDAXUser("https://api.gdax.com", "", "", "")
   while num_fails < num_fails_max
       m_start = until - Dates.Second(granularity) * 349
       resp = getHistoricRates(user, product_id, m_start, until, granularity)
       if Requests.statuscode(resp) != 200
           num_fails += 1
           msg = Requests.json(resp)
           verbose && @printf("Error respond: %ls\n", msg)
           sleep(15)
           continue
       end

       data = Requests.json(resp)
       if isempty(data)
           #does not mean that there is no data left
           verbose && @printf("Empty data\n")
           break
       end

       append!(storage, data)

       times = [first(x) for x in data]
       first_time = minimum(times)
       next_until = Dates.unix2datetime(first_time)

       if next_until == until
           verbose && @printf("The same start\n")
           break
       end

       until = next_until
       if until < from
           break
       end

       verbose && @printf("[Loading %ls] Start: %ls. Total points loaded: %d\n", product_id, until, length(storage))
       sleep(rand() + 2)
   end

   return storage
end
