"Parse the input data"
function parse_matpower(file::String)
    pm_data = _PM.parse_file(file)
    pm_data["method"] = "PMs"
    if haskey(pm_data, "gensub")
        for (i,gen) in pm_data["gensub"]
            pm_data["gen"][i]["rs"] = gen["rs"]
            pm_data["gen"][i]["xs"] = gen["xs"]
        end
        delete!(pm_data, "gensub")
    else
        # TODO verify pu values as inputs
        if haskey(pm_data, "gen")
            for (_,gen) in pm_data["gen"]
                gen["rs"] = 0
                gen["xs"] = .1
            end
        end
    end
    return pm_data
end
