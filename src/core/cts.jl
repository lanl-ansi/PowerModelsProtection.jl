"""
Function to add a current transformer to circuit dictionary.

Inputs(in order):

Circuit dictionary, monitored element, name of fuse, primary and secondary turns. Turns entered seperately and stored as a vector.
"""
function add_ct(data::Dict{String,Any}, element::Union{String,SubString{String}}, id::Union{String,SubString{String}}, n_p::Number, n_s::Number;kwargs...)
    if !haskey(data, "protection")
        data["protection"] = Dict{String,Any}()
    end
    if haskey(data["line"], "$element")
        if !haskey(data["protection"], "C_Transformers")
            data["protection"]["C_Transformers"] = Dict{String,Any}()
        end
        if haskey(data["protection"]["C_Transformers"], "$id")
            @info "$id has been redefined"
        end
        data["protection"]["C_Transformers"]["$id"] = Dict{String,Any}(
            "turns" => [n_p,n_s],
            "element" => element
        )
        kwargs_dict = Dict(kwargs)
        new_dict = _add_dict(kwargs_dict)
        merge!(data["protection"]["C_Transformers"]["$id"], new_dict)
    else
        @info "Circuit element $element does not exist. No CT added."
    end
end
