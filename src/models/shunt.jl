
function _map_ravens2math_mc_admittance_shunt!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "shunt")
        for (name, shunt) in data_math["shunt"]
            println(shunt)
            println(oooo)
            y = shunt["gs"] + 1im .* shunt["bs"]
            y1 = y
            y2 = -y
            y3 = y2
            y4 = y
            shunt["p_matrix"] = [y1 y2; y3 y4]
        end
    end
end