""
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
        nw_ref[:active_fault]["bus_i"] = ref[:nw][nw_id][:bus_lookup][nw_ref[:active_fault]["bus_i"]]
    end
end

function ref_add_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end
    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:nw][nw_id]
        nw_ref[:solar] = Dict{Int, Any}()
        for (i, gen) in nw_data["gen"]
            if occursin("pvsystem", gen["source_id"]) 
                nw_ref[:solar][gen["gen_bus"]] = parse(Int, i)
                gen["i_max"] = 1/gen["dss"]["vminpu"] * gen["dss"]["kva"]/ref[:nw][0][:baseMVA]/1000/3
                gen["solar_max"] = gen["dss"]["irradiance"] * gen["dss"]["pmpp"]/ref[:nw][0][:baseMVA]/1000
                gen["kva"] = gen["dss"]["kva"]/ref[:nw][0][:baseMVA]/1000
                gen["pf"] = gen["dss"]["pf"]
                delete!(gen, "dss")
            end
        end
    end
end