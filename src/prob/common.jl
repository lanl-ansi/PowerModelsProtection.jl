
function instantiate_mc_admittance_model(
    data::Dict{String,<:Any}; 
    loading::Bool=true,
    ref_extensions::Vector{<:Function}=Function[],
    multinetwork::Bool=ismultinetwork(data),
    global_keys::Set{String}=Set{String}(),
    eng2math_extensions::Vector{<:Function}=Function[],
    eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
    make_pu_extensions::Vector{<:Function}=Function[],
    kwargs...
    )

    if data["data_model"] == _PMD.ENGINEERING
        data_math = transform_admittance_data_model(
            data; 
            eng2math_extensions = Function[],
            eng2math_passthrough=_pmp_eng2math_passthrough,
            make_pu_extensions=make_pu_extensions,
        )
    end
    y_matrix, c_matrix = build_mc_admittance_matrix(data_math;loading=loading)
    z_matrix = inv(y_matrix)
    v = build_mc_voltage_vector(data_math)
    i = build_mc_current_vector(data_math, v)
    return AdmittanceModel(data_math, y_matrix, z_matrix, c_matrix, v, i)
end