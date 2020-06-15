
function run_mc_model(data::Dict{String,<:Any}, model_type::Type, solver, build_mc::Function; ref_extensions::Vector{<:Function}=Vector{Function}([]), make_si=!get(data, "per_unit", false), multinetwork::Bool=false, kwargs...)::Dict{String,Any}
    if get(data, "data_model", _PMD.MATHEMATICAL) == _PMD.ENGINEERING
        active_fault = deepcopy(data["active_fault"])
        fault = deepcopy(data["fault"])
        data_math = _PMD.transform_data_model(data; build_multinetwork=multinetwork)
        data_math["active_fault"] = deepcopy(active_fault)
        # data_math["fault"] = fault
        # result = _PM.run_model(data_math, model_type, solver, build_mc; ref_extensions=[_PMD.ref_add_arcs_transformer!, ref_extensions...], multiconductor=true, multinetwork=multinetwork, solution_processors=[solution_fs!], kwargs...)
        result = _PM.run_model(data_math, model_type, solver, build_mc; ref_extensions=[_PMD.ref_add_arcs_transformer!, ref_extensions...], multiconductor=true, multinetwork=multinetwork, solution_processors=[solution_fs!], kwargs...)
        result["solution"] = _PMD.transform_solution(result["solution"], data_math; make_si=make_si)
        add_solution!(result["solution"], data_math)
    elseif get(data, "data_model", _PMD.MATHEMATICAL) == _PMD.MATHEMATICAL
        result = _PM.run_model(data, model_type, solver, build_mc; ref_extensions=[_PMD.ref_add_arcs_transformer!, ref_extensions...], multiconductor=true, multinetwork=multinetwork, kwargs...)
    end

    return result
end