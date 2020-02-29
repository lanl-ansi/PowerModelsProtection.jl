

function parse_file(file::String; import_all=false, validate=true)
    pm_data = open(file) do io
        pm_data = parse_file(io; import_all=import_all, validate=validate, filetype=split(lowercase(file), '.')[end])
    end
    return pm_data
end

"Parses the iostream from a file"
function parse_file(io::IO; import_all=false, validate=true, filetype="json")
    if filetype == "m"
        pm_data = parse_matpower(io, validate=validate)
    elseif filetype == "raw"
        Memento.info(_LOGGER, "The PSS(R)E parser currently supports buses, loads, shunts, generators, branches, transformers, and dc lines")
        pm_data = parse_psse(io; import_all=import_all, validate=validate)
    elseif filetype == "json"
        pm_data = parse_json(io; validate=validate)
    else
        Memento.error(_LOGGER, "Unrecognized filetype")
    end

    return pm_data
end

