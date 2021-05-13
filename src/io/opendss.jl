"Parse opendss data file using PMD and math model"
function parse_opendss(file::String; kwargs...)
    pm_data = _PMD.parse_file(file; dss2eng_extensions=[_dss2eng_solar_dynamics!, _dss2eng_gen_dynamics!], kwargs...)
    pm_data["method"] = "PMD"
    return pm_data
end
