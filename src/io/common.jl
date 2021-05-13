"Parse the input data"
function parse_file(file::String; kwargs...)
    filetype = split(lowercase(file), '.')[end]
    if filetype == "m"
        pm_data = parse_matpower(file)
    elseif filetype == "dss"
        pm_data = parse_opendss(file; import_all=true, kwargs...)
    end
    return pm_data
end
