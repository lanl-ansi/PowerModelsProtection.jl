
function check_pf!(data::Dict{String,Any}, solver)
    if haskey(data, "pf")
        if data["pf"] == "true" 
            add_pf_data!(data, solver)
        end
    else
        add_pf_data!(data, solver)
    end
end

function add_pf_data!(data::Dict{String,Any}, solver)
    result = _PMs.run_pf(data, _PMs.ACPPowerModel, solver)
    add_pf_data!(data, result)
end

function add_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})
    if result["primal_status"] == MOI.FEASIBLE_POINT
        for (i, bus) in result["solution"]["bus"]
            data["bus"][i]["vm"] = bus["vm"]
            data["bus"][i]["va"] = bus["va"]
        end
    else
        Memento.info(_LOGGER, "The model power flow returned infeasible")
    end
end
