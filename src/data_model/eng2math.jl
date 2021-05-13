""
function _eng2math_fault!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    if !haskey(data_math, "fault")
        data_math["fault"] = Dict{String,Any}()
    end

    pass_props = ["status", "f_connections", "t_connections", "g", "b"]

    for (name, eng_obj) in get(data_eng, "fault", Dict())
        math_obj = _PMD._init_math_obj("fault", name, eng_obj, length(data_math["fault"])+1; pass_props=pass_props)

        math_obj["fault_bus"] = data_math["bus_lookup"][eng_obj["bus"]]

        data_math["fault"]["$(math_obj["index"])"] = math_obj

        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => "fault.$(math_obj["index"])",
            "unmap_function" => "_map_math2eng_fault!",
            "apply_to_subnetworks" => true,
        ))
    end
end


const _pmp_eng2math_passthrough = Dict{String,Vector{String}}(
        "generator" => String["zr", "zx", "grid_forming"],
        "solar" => String["i_max", "solar_max", "kva", "pf", "grid_forming"],
        "voltage_source" => String["zr", "zx", "grid_forming"],
    )


transform_data_model(
    data::Dict{String,<:Any};
    eng2math_extensions::Vector{<:Function}=Function[],
    make_pu_extensions::Vector{<:Function}=Function[],
    kwargs...) = _PMD.transform_data_model(
        data;
        eng2math_extensions=[_eng2math_fault!, eng2math_extensions...],
        eng2math_passthrough=_pmp_eng2math_passthrough,
        make_pu_extensions=[_rebase_pu_fault!, _rebase_pu_gen_dynamics!, make_pu_extensions...],
        kwargs...)
