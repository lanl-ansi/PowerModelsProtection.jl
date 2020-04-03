""
function parse_file(file::String)
    filetype = split(lowercase(file), '.')[end]
    if filetype == "m"
        pm_data = parse_matpower(file)
    elseif filetype == "dss"
        pm_data = parse_opendss(file)
    end
    return pm_data
end
