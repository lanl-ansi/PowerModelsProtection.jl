
"admittance model"
function _map_ravens2math_mc_admittance_line!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "branch")
        for (name, branch) in data_math["branch"]
            if branch["br_status"] == 1
                z = branch["br_r"] + 1im .* branch["br_x"]
                y_from = branch["g_fr"] + 1im .* branch["b_fr"]
                y_to = branch["g_to"] + 1im .* branch["b_to"]
                z1 = inv(z) + y_from 
                z2 = -inv(z)
                z3 = z2
                z4 = inv(z) + y_to 
                branch["p_matrix"] = [z1 z2; z3 z4]
                for i = 1:size(branch["p_matrix"])[1]
                    branch["p_matrix"][i,i] += 1e-9-1e-9im
                end
                # if abs(LA.det(branch["p_matrix"])) > 100 || LA.cond(branch["p_matrix"]) > 1000
                #     println("Branch $(branch["name"]) matrix has high condition")
                # end
            end
        end
    end
end

