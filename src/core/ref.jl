"Adds the fault to the model"
function ref_add_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end
    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:nw][nw_id]
        nw_ref[:active_fault] = data["active_fault"]
    end
end


"Adds the fault to the model for multiconductor"
function ref_add_mc_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end
    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:nw][nw_id]
        nw_ref[:active_fault] = data["active_fault"]
        nw_ref[:active_fault]["bus_i"] = ref[:nw][nw_id][:bus_lookup][nw_ref[:active_fault]["bus_i"]]
    end
end


"Calculates the p[ower from solar based on inputs"
function ref_add_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end
    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:nw][nw_id]
        nw_ref[:solar_gfli] = Dict{Int,Any}()
        nw_ref[:solar_gfmi] = Dict{Int,Any}()
        for (i, gen) in nw_data["gen"]
            if occursin("pvsystem", gen["source_id"])
                if haskey(gen, "grid_forming")
                    gen["grid_forming"] ? nw_ref[:solar_gfmi][gen["gen_bus"]] = parse(Int, i) : nw_ref[:solar_gfli][gen["gen_bus"]] = parse(Int, i)
                else
                    nw_ref[:solar_gfli][gen["gen_bus"]] = parse(Int, i)
                end
                haskey(gen, "i_max") ? nothing : gen["i_max"] = 1 / gen["dss"]["vminpu"] * gen["dss"]["kva"] / ref[:nw][0][:baseMVA] / 1000 / 3
                haskey(gen, "solar_max") ? nothing : gen["solar_max"] = gen["dss"]["irradiance"] * gen["dss"]["pmpp"] / ref[:nw][0][:baseMVA] / 1000
                haskey(gen, "kva") ? nothing : gen["kva"] = gen["dss"]["kva"] / ref[:nw][0][:baseMVA] / 1000
                haskey(gen, "pf") ? nothing : gen["pf"] = gen["dss"]["pf"]
                delete!(gen, "dss")
            end
        end
    end
end
