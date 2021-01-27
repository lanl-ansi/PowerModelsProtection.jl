"Parse opendss data file using PMD and math model"
function parse_opendss(file::String; kwargs...)
    pm_data = _PMD.parse_file(file; data_model = _PMD.MATHEMATICAL, kwargs...)
    pm_data["method"] = "PMD"
    return pm_data
end
