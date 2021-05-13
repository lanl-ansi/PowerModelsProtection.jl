"Adds the fault to the model"
function ref_add_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end
    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:it][_PM.pm_it_sym][:nw][nw_id]
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
        nw_ref = ref[:it][_PMD.pmd_it_sym][:nw][nw_id]
        nw_ref[:active_fault] = data["active_fault"]
    end
end


"Calculates the power from solar based on inputs"
function ref_add_mc_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_mc_solar!, ref, data; apply_to_subnetworks=true)
end


"Calculates the power from solar based on inputs"
function _ref_add_mc_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    ref[:solar_gfli] = Dict{Int,Any}()
    ref[:solar_gfmi] = Dict{Int,Any}()

    for (i, gen) in data["gen"]
        @debug "Adding solar refs for gen $i"

        if occursin("solar", gen["source_id"])
            if haskey(gen, "grid_forming")
                @debug "Gen $i is grid-forming inverter:"
                if gen["grid_forming"]
                    ref[:solar_gfmi][parse(Int, i)] = gen["gen_bus"]
                else
                    ref[:solar_gfli][parse(Int, i)] = gen["gen_bus"]
                end
            else
                ref[:solar_gfli][parse(Int, i)] = gen["gen_bus"]
            end
        end
    end
end

