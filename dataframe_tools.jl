function df2dict(df; ts_keys=[], n_elems=0)
    ts_set = Set(ts_keys)
    keys = names(df)
    recs = []

    for i in 1:size(df,1)
        x = df[i,:]
        y = Dict()

        for k in keys
            if k in ts_set
                y[String(k)] = zeros(n_elems)
            else
                y[String(k)] = x[k][1]
            end
        end

        push!(recs, y)
    end

    return recs
end
 
