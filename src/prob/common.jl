""
function run_mc_model(data::Dict{String,<:Any}, model_type::Type, solver, build_mc::Function; ref_extensions::Vector{<:Function}=Vector{Function}([]), make_si=!get(data, "per_unit", false), multinetwork::Bool=false, kwargs...)::Dict{String,Any}
    result = _PM.run_model(data, model_type, solver, build_mc; ref_extensions=[_PMD.ref_add_arcs_transformer!, ref_extensions...], multiconductor=true, multinetwork=multinetwork, solution_processors=[solution_fs!], kwargs...)
    if haskey(data, "active_fault") 
        fault_current = result["solution"]["fault_current"]  
        hold_solution = result["solution"]
        delete!(result["solution"], "fault_current")
        result["solution"] = _PMD.transform_solution(result["solution"], data; make_si=make_si)
        result["solution"]["fault_current"] = fault_current
        result["solution"]["gen"] = hold_solution["gen"]
        result["solution"]["bus"] = hold_solution["bus"]
        add_fault_solution!(result["solution"], data)
    else 
        result["solution"] = _PMD.transform_solution(result["solution"], data; make_si=make_si)
    end
    return result
end
