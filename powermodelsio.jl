using Printf, DataFrames

function print_dict(x; drop=["index","bus_i"])
    drop_set = Set(drop)

    for (k,y) in x
        if k in drop_set
            continue
        end

        println("$k: $y")
    end
end

function print_bus(case, bid)
    bus = case["bus"]["$bid"]

    # print the loads that connect to this bus
    println("Bus $bid")
    print_dict(bus)
    println()

    bus_loads = [x for x in values(case["load"]) if x["load_bus"] == bid]

    if length(bus_loads) > 0
        println("Loads:")
        @printf "%5s  %8s, %8s, %8s\n" "" "index" "pd" "qd"

        for (i,x) in enumerate(values(case["load"]))
            @printf "%5d: %8d, %8.3f, %8.3f\n" i x["index"] x["pd"] x["qd"]
        end
    else
        println("No attached loads")
    end

    # print the generators that connect 
    bus_gens = [x for x in values(case["gen"]) if x["gen_bus"] == bid]

    if length(bus_gens) > 0
        println()
        println("Generators:")
        @printf "%5s  %8s, %8s, %8s, %8s, %8s, %8s, %8s\n" "" "index" "pg" "qg" "pmin" "pmax" "qmin" "qmax"
    

        for (i,x) in enumerate(bus_gens)
            @printf "%5d: %8d, %8.3f, %8.3f, %8.3f, %8.3f, %8.3f, %8.3f\n" i x["index"] x["pg"] x["qg"] x["pmin"] x["pmax"] x["qmin"] x["qmax"]
        end
    else
        println("No attached generators")
    end
        
    # print the branches that connect 
    bus_branches = [x for x in values(case["branch"]) if (x["f_bus"] == bid || x["t_bus"] == bid)]

    if length(bus_branches) > 0
        println()
        println("Branches")
        # f_bus, t_bus,  br_r,  br_x, shift, rate_a, rate_b, rate_c
        @printf "%5s  %8s, %8s, %8s %8s, %8s, %8s, %8s\n" "" "f_bus" "t_bus" "is_xf" "br_r" "br_x" "shift" "rate_a"


        for (i,x) in enumerate(bus_branches)
            @printf "%5d: %8d, %8d, %8d %8.3f, %8.3f, %8.3f, %8.3f\n" i x["f_bus"] x["t_bus"] x["transformer"] x["br_r"] x["br_x"] x["shift"] x["rate_a"]
        end
    end

end

function to_df(case, table_name, result=nothing)
    df = DataFrame()
    table = case[table_name]
  
    cols = collect(keys(table))
    
    df[!, :index] = cols

    for k in keys(first(values(table)))
        col = []

        for x in values(table)
            if k in keys(x)
                push!(col, x[k])
            else
                push!(col, nothing)
            end
        end

        df[!, Symbol(k)] = col 
    end 
    
    if result !== nothing
        soln_table = result["solution"][table_name]

        for k in keys(first(values(soln_table)))
            col = [x[k] for x in values(soln_table)]

            df[!, Symbol(k)] = col 
        end 
    end
    
    return df
end