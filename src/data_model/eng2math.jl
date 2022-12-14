"helper function to transformer fault objects from ENGINEERING to MATHEMATICAL data models"
function _eng2math_fault!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    if !haskey(data_math, "fault")
        data_math["fault"] = Dict{String,Any}()
    end

    pass_props = ["status", "connections", "g", "b"]

    for (name, eng_obj) in get(data_eng, "fault", Dict())
        # TODO bug in PMD, kron_reduced not in data_eng, apply by default for now
        if true # get(data_eng, "kron_reduced", false)
            # kron reduce g, b, connections
            # TODO better kr_neutral detection
            f = _PMD._kron_reduce_branch!(eng_obj, String[], ["g", "b"], eng_obj["connections"], 4)
            _PMD._apply_filter!(eng_obj, ["connections"], f)
        end

        math_obj = _PMD._init_math_obj("fault", name, eng_obj, length(data_math["fault"])+1; pass_props=pass_props)

        math_obj["fault_bus"] = data_math["bus_lookup"][eng_obj["bus"]]

        data_math["fault"]["$(math_obj["index"])"] = math_obj

        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => "fault.$(math_obj["index"])",
            "unmap_function" => "_map_math2eng_fault!",
            "apply_to_subnetworks" => true,
        ))
    end
end


"helper function to transform protection equipment objects from ENGINEERING to MATHEMATICAL data models"
function _eng2math_protection!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    map_dict = Dict{String,Any}("bus"=>Dict{String,Any}(),"branch"=>Dict{String,Any}())
    for (_, obj) in get(data_math,"branch",Dict())
        map_dict["branch"]["$(obj["name"])"] = obj["index"]
    end
    for (_, obj) in get(data_math,"bus",Dict())
        map_dict["bus"]["$(obj["name"])"] = obj["index"]
    end
    ct_map = Dict{String,Any}()
    curve_map = Dict{String,Any}()

    if "C_Transformers" in keys(data_eng["protection"])
        pass_props = ["turns","element"]
        if !haskey(data_math,"c_transformer")
            data_math["c_transformer"] = Dict{String,Any}()
        end
        for (name,eng_obj) in get(data_eng["protection"],"C_Transformers",Dict())
            math_obj = _PMD._init_math_obj("c_transformer",name,eng_obj,length(data_math["c_transformer"])+1;pass_props=pass_props)
            math_obj["prot_obj"] = :branch
            math_obj["element_enum"] = map_dict["branch"]["$(math_obj["element"])"]
            data_math["c_transformer"]["$(math_obj["index"])"] = math_obj
            push!(data_math["map"], Dict{String,Any}(
                "from" => name,
                "to" => "c_transformer.$(math_obj["index"])",
                "unmap_function" => "_map_math2eng_protection!",
                "apply_to_subnetworks" => true,
                )
            )
            ct_map["$name"] = length(data_math["c_transformer"])
        end
    end

    if "relays" in keys(data_eng["protection"])
        pass_props = ["TDS","TS","phase","breaker_time","shots","type","CT","CTs","trip","restraint","element2","state"]
        if !haskey(data_math,"relay")
            data_math["relay"] = Dict{String,Any}()
        end
        for (element_name,relay_dict) in get(data_eng["protection"],"relays",Dict())
            for (name, eng_obj) in relay_dict
                math_obj = _PMD._init_math_obj("relay", name, eng_obj, length(data_math["relay"])+1; pass_props=pass_props)
                if haskey(math_obj, "CT")
                    math_obj["ct_enum"] = ct_map["$(math_obj["CT"])"]
                elseif haskey(math_obj, "CTs")
                    math_obj["cts_enum"] = []
                    for i=1:length(math_obj["CTs"])
                        push!(math_obj["cts_enum"],ct_map["$(math_obj["CTs"][i])"])
                    end
                end
                if haskey(map_dict["branch"],element_name)
                    math_obj["prot_obj"] = :branch
                    math_obj["element_enum"] = map_dict["branch"]["$element_name"]
                else
                    math_obj["prot_obj"] = :bus
                    math_obj["element_enum"] = map_dict["bus"]["$element_name"]
                end

                if haskey(math_obj,"element2")
                    math_obj["element2_enum"] = map_dict["branch"]["$(math_obj["element2"])"]
                end
                math_obj["element"] = element_name
                data_math["relay"]["$(math_obj["index"])"] = math_obj
                push!(data_math["map"], Dict{String,Any}(
                    "from" => name,
                    "to" => "relay.$(math_obj["index"])",
                    "unmap_function" => "_map_math2eng_protection!",
                    "apply_to_subnetworks" => true,
                    )
                )
            end
        end
    end

    if "curves" in keys(data_eng["protection"])
        pass_props = ["curve_mat"]
        if !haskey(data_math,"curve")
            data_math["curve"] = Dict{String,Any}()
        end
        for (name,eng_obj) in get(data_eng["protection"],"curves",Dict())
            math_obj = _PMD._init_math_obj("curve",name,eng_obj,length(data_math["curve"])+1;pass_props=pass_props)
            data_math["curve"]["$(math_obj["index"])"] = math_obj
            push!(data_math["map"], Dict{String,Any}(
                "from" => name,
                "to" => "curve.$(math_obj["index"])",
                "unmap_function" => "_map_math2eng_protection!",
                "apply_to_subnetworks" => true,
                )
            )
            curve_map["$name"] = length(data_math["curve"])
        end
    end

    if "fuses" in keys(data_eng["protection"])
        pass_props = ["min_melt_curve","max_clear_curve","phase"]
        if !haskey(data_math,"fuse")
            data_math["fuse"] = Dict{String,Any}()
        end
        for (line_name,fuse_dict) in get(data_eng["protection"],"fuses",Dict())
            for (name,eng_obj) in fuse_dict
                math_obj = _PMD._init_math_obj("fuse",name,eng_obj,length(data_math["fuse"])+1;pass_props=pass_props)
                math_obj["element"] = line_name
                math_obj["element_enum"] = map_dict["branch"]["$line_name"]
                if (typeof(math_obj["max_clear_curve"]) == String) || (typeof(math_obj["max_clear_curve"]) == SubString{String})
                    math_obj["max_clear_curve_enum"] = curve_map["$(math_obj["max_clear_curve"])"]
                end
                if (typeof(math_obj["min_melt_curve"]) == String) || (typeof(math_obj["min_melt_curve"]) == SubString{String})
                    math_obj["min_melt_curve_enum"] = curve_map["$(math_obj["min_melt_curve"])"]
                end
                data_math["fuse"]["$(math_obj["index"])"] = math_obj
                push!(data_math["map"], Dict{String,Any}(
                    "from" => name,
                    "to" => "fuse.$(math_obj["index"])",
                    "unmap_function" => "_map_math2eng_protection!",
                    "apply_to_subnetworks" => true,
                    )
                )
            end
        end
    end
end


"""
"""
function _eng2math_storage!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    for (indx, obj) in get(data_math,"storage",Dict())
        if !haskey(obj, "dss")
            continue
        end

        obj["inverter"] = string(get(data_eng["storage"][obj["dss"]["name"]], "inverter", "GRID_FOLLOWING"))
        ncnd = length(obj["connections"])
        if !haskey(obj, "pmax")
            obj["pmax"] =  fill(abs(obj["ps"])/ncnd, ncnd)
            obj["pmin"] =  fill(-abs(obj["ps"])/ncnd, ncnd)
            obj["qmax"] =  fill(obj["ps"]/ncnd, ncnd)
            obj["qmin"] =  fill(-obj["ps"]/ncnd, ncnd)
        end
    end
end


"""
"""
function _eng2math_solar!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
end


"field/values to passthrough from the ENGINEERING to MATHEMATICAL data models"
const _pmp_eng2math_passthrough = Dict{String,Vector{String}}(
    "generator" => String["zr", "zx", "grid_forming", "gen_model"],
    "solar" => String["imax", "vminpu", "kva", "pf", "grid_forming", "gen_model"],
    "voltage_source" => String["zr", "zx", "grid_forming", "gen_model"],
    "storage" => String["pmax", "pmin", "imax", "inverter", "gen_model"],
)


"custom version of `transform_data_model` from PowerModelsDistribution for easy model transformation"
transform_data_model(
    data::Dict{String,<:Any};
    eng2math_extensions::Vector{<:Function}=Function[],
    make_pu_extensions::Vector{<:Function}=Function[],
    kwargs...) = _PMD.transform_data_model(
        data;
        eng2math_extensions=[_eng2math_fault!, _eng2math_protection!, eng2math_extensions...],
        eng2math_passthrough=_pmp_eng2math_passthrough,
        make_pu_extensions=[_rebase_pu_fault!, _rebase_pu_gen_dynamics!, make_pu_extensions...],
        kwargs...)
