struct AdmittanceModel
    data::Dict{String,<:Any}
    y::Matrix{Complex{Float64}}
    z::Matrix{Complex{Float64}}
    v::Matrix{Complex{Float64}}
    i::Matrix{Complex{Float64}}
    delta_i_control::Matrix{Complex{Float64}}
    delta_i::Matrix{Complex{Float64}}
end

