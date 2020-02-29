function parse_matpower(io::IO; validate=true)::Dict
    pm_data = _PMs.parse_matpower(io, validate=validate)

    # if haskey(pm_data, "fault")
    #     println(pm_data["fault"])
    # else
    #     # add all buses with default impedance
    # end

    if haskey(pm_data, "gensub")
        for (i,gen) in pm_data["gensub"]
            pm_data["gen"][i]["rs"] = gen["rs"]
            pm_data["gen"][i]["xs"] = gen["xs"]
        end
        delete!(pm_data, "gensub")
    else
        # default values need address pu values?
        for (i,gen) in pm_data["gensub"]
            pm_data["gen"][i]["rs"] = 0
            pm_data["gen"][i]["xs"] = .1
        end
    end
end

