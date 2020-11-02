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
        for (i,gen) in pm_data["gensub"]
            pm_data["gen"][i]["rs"] = 0
            pm_data["gen"][i]["xs"] = .1
        end
    end
    return pm_data
end
