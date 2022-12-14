"""
	ref_add_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})

Adds the fault to the model
"""
function ref_add_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PM.apply_pm!(_ref_add_fault!, ref, data; apply_to_subnetworks=true)
end


"Adds the fault to the model"
function _ref_add_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    ref[:fault] = Dict(x for x in get(ref, :fault, Dict{Int,Any}()) if x.second["status"] != 0)
    ref[:fault_buses] = Dict{Int,Int}(x.second["fault_bus"] => x.first for x in ref[:fault])
end


"""
	ref_add_mc_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})

Adds the fault to the model for multiconductor
"""
function ref_add_mc_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_mc_fault!, ref, data; apply_to_subnetworks=true)
end


"Adds the fault to the model for multiconductor"
function _ref_add_mc_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    ref[:fault] = Dict(x for x in get(ref, :fault, Dict{Int,Any}()) if x.second["status"] != 0 && x.second["fault_bus"] in keys(ref[:bus]))
    ref[:fault_buses] = Dict{Int,Int}(x.second["fault_bus"] => x.first for x in ref[:fault])
end


"""
	ref_add_mc_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})

Calculates the power from solar based on inputs
"""
function ref_add_mc_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_mc_solar!, ref, data; apply_to_subnetworks=true)
end


"Calculates the power from solar based on inputs"
function _ref_add_mc_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    ref[:solar_gfli] = []
    ref[:solar_gfmi] = []
    for (i, gen) in filter(x->x.second["gen_status"]!=0, get(data, "gen", Dict()))
        @debug "Adding solar refs for gen $i"
        if occursin("solar", gen["source_id"])
            !haskey(gen, "gen_model") ? gen["gen_model"] = 7 : nothing
            if haskey(gen, "grid_forming")
                @debug "Gen $i is grid-forming inverter:"
                if gen["grid_forming"]
                    append!(ref[:solar_gfmi], parse(Int, i))
                else
                    append!(ref[:solar_gfli], parse(Int,i))
                    gen["pmin"] = gen["pmax"]
                end
            else
                append!(ref[:solar_gfli], parse(Int,i))
                gen["pmin"] = gen["pmax"]
            end
        end
    end
end


"""
	ref_add_grid_forming_bus!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})

identifies grid forming buses
"""
function ref_add_grid_forming_bus!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_grid_forming_bus!, ref, data; apply_to_subnetworks=true)
end


"identifies grid forming buses"
function _ref_add_grid_forming_bus!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    grid_forming_buses = Set([gen["gen_bus"] for (_,gen) in ref[:gen] if get(gen, "grid_forming", false)])
    ref[:grid_forming] = Dict{Int,Bool}(i => i in grid_forming_buses for (i,_) in ref[:bus])
end


"""
	ref_add_mc_storage!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})

Add solar inverters to the model
"""
function ref_add_mc_storage!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_mc_storage!, ref, data; apply_to_subnetworks=true)
end


"Add battery energy storage to the model"
function _ref_add_mc_storage!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    is_gfmi = x -> haskey(x, "inverter") && x["inverter"] == "GRID_FORMING"

    ref[:storage_gfmi] = [storage["index"] for (_,storage) in ref[:storage] if is_gfmi(storage)]
    ref[:storage_gfli] = [storage["index"] for (_,storage) in ref[:storage] if !is_gfmi(storage)]
end
