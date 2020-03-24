
function parse_opendss(file::String)
    pm_data = _PMD.parse_file(file)
    pm_data["method"] = "PMD"
    for (i,gen) in pm_data["gen"]
        !haskey(gen, "rs") ? pm_data["gen"][i]["rs"] = [0.0 for c in gen["active_phases"]] : nothing
        !haskey(gen, "xs") ? pm_data["gen"][i]["xs"] = [0.1 for c in gen["active_phases"]] : nothing
    end
    return pm_data
end
