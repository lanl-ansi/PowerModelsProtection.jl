"""
    parse_opendss(file::String; method::Union{String,Missing}=missing, kwargs...)

Parse opendss data file using PowerModelsDistribution parse_file function into an ENGINEERING
data model adding some extra data transformations specific to fault studies.

`method` should be `missing` or `"PMD"`.

`kwargs` can be any valid keyword arguments from PowerModelsDistribution's `parse_file` function.
"""
function parse_opendss(file::String; method::Union{String,Missing}=missing, kwargs...)
    pm_data = _PMD.parse_file(file; bank_transformers=false, dss2eng_extensions=[_dss2eng_solar_dynamics!, _dss2eng_load_dynamics!, _dss2eng_voltage_source_dynamics!, _dss2eng_gen_dynamics!, _dss2eng_transformer_dynamics!, _dss2eng_issues!], kwargs...)
    if ismissing(method)
        pm_data["method"] = "PMD"
    else
        pm_data["method"] = method
    end

    return pm_data
end
