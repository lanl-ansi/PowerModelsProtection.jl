""
function run_mc_model(data::Dict{String,<:Any}, model_type::Type, solver, build_mc::Function; ref_extensions::Vector{<:Function}=Vector{Function}([]), make_si=!get(data, "per_unit", false), multinetwork::Bool=false, kwargs...)::Dict{String,Any}
    result = _PM.run_model(data, model_type, solver, build_mc; ref_extensions=[_PMD.ref_add_arcs_transformer!, ref_extensions...], multiconductor=true, multinetwork=multinetwork, solution_processors=[solution_fs!], kwargs...)
    result["solution"] = _PMD.transform_solution(result["solution"], data; make_si=make_si)
    add_fault_solution!(result["solution"], data)
    return result
end
