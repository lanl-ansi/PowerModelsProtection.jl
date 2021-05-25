"Parse opendss data file using PMD and math model"
function parse_opendss(file::String; method::Union{String,Missing}=missing, kwargs...)
    pm_data = _PMD.parse_file(file; dss2eng_extensions=[_dss2eng_solar_dynamics!, _dss2eng_gen_dynamics!], kwargs...)

    if ismissing(method)
        pm_data["method"] = "PMD"
    else
        pm_data["method"] = method
    end

    return pm_data
end
