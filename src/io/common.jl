"Parse the input data"
function parse_file(
    file::String;
    method::Union{String,Missing}=missing,
    add_gensub::Bool=false,
    flat_start::Bool=false,
    neglect_line_charging::Bool=false,
    neglect_transformer::Bool=false,
    zero_gen_setpoints::Bool=false,
    import_all::Bool=true,
    kwargs...)

    filetype = split(lowercase(file), '.')[end]
    if filetype == "m"
        pm_data = parse_matpower(
            file;
            import_all=import_all,
            method=method,
            add_gensub=add_gensub,
            flat_start=flat_start,
            neglect_line_charging=neglect_line_charging,
            neglect_transformer=neglect_transformer,
            zero_gen_setpoints=zero_gen_setpoints
        )
    elseif filetype == "dss"
        pm_data = parse_opendss(
            file;
            import_all=import_all,
            method=method,
            kwargs...
        )
    end

    return pm_data
end
