

"field/values to passthrough from the ENGINEERING to MATHEMATICAL data models"
const _pmp_dss2math_passthrough = Dict{String,Vector{String}}(
        "generator" => String["zr", "zx", "gen_model", "xdp", "rp", "xdpp", "vnom_kv", "phases", "response", "element"],
        "solar" => String["i_max", "solar_max", "kva", "pf", "grid_forming", "balanced", "vminpu", "transformer", "type", "pv_model", "phases", "response", "element", "fault_model", "i_nom", "i+", "i-", "p_control"],
        "voltage_source" => String["zr", "zx", "phases", "response", "element"],
        "load" => String["vminpu", "vmaxpu", "response", "phases", "element"],
        "transformer" => String["leadlag", "phases", "element"]
    )


# "custom version of `transform_data_model` from PowerModelsDistribution for easy model transformation"
# transform_data_model(
#     data::Dict{String,<:Any};
#     eng2math_extensions::Vector{<:Function}=Function[],
#     make_pu_extensions::Vector{<:Function}=Function[],
#     kwargs...) = _PMD.transform_data_model(
#     data;
#     eng2math_extensions=[_eng2math_fault!, _eng2math_protection!, eng2math_extensions...],
#     eng2math_passthrough=_pmp_eng2math_passthrough,
#     make_pu_extensions=[_rebase_pu_fault!, _rebase_pu_gen_dynamics!, make_pu_extensions...],
#     kwargs...)


# # "admittance model"
# # const _mc_admittance_asset_types = [
# #     "line", "voltage_source", "load", "transformer", "shunt", "solar", "generator"
# # ]

function transform_data_model_mc_dss(
    data::Dict{String,<:Any};
    kron_reduce::Bool=true,
    phase_project::Bool=false,
    multinetwork::Bool=false,
    global_keys::Set{String}=Set{String}(),
    dss2math_passthrough::Dict{String,<:Vector{<:String}}=_pmp_dss2math_passthrough,
    dss2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=false,
    make_pu_extensions::Vector{<:Function}=Function[],
    build_model::Bool=false,
    correct_network_data::Bool=true,
    kwargs...,
    )::Dict{String,Any}

    data_math = _map_dss2math_mc_admittance(
        data;
        multinetwork=multinetwork,
        kron_reduce=kron_reduce,
        phase_project=phase_project,
        dss2math_extensions=dss2math_extensions,
        dss2math_passthrough=dss2math_passthrough,
        global_keys=global_keys,
    )

    correct_network_data && correct_network_data!(data_math; make_pu=make_pu, make_pu_extensions=make_pu_extensions)

    _apply_dss_mc_admittance!(_map_dss2math_mc_admittance_nw!, data_math, dss2math_passthrough=dss2math_passthrough, dss2math_extensions=dss2math_extensions)

    correct_grounds!(data_math)

    # populate_bus_voltages!(data_math)

    add_mc_last_current_keys!(data_math)

    return data_math
end


function _apply_dss_mc_admittance!(func!::Function, data1::Dict{String,<:Any}; kwargs...)
    func!(data1; kwargs...)
end


function _map_dss2math_mc_admittance_nw!(data_math::Dict{String,<:Any}; dss2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(), dss2math_extensions::Vector{<:Function}=Function[])
    for type in _mc_admittance_asset_types # --> anything from missing from the model needed for the solve or admittance matrix maybe per unit to actual
        getfield(PowerModelsProtection, Symbol("_map_mc_admittance_$(type)!"))(data_math; pass_props=get(dss2math_passthrough, type, String[]))
    end
end


function _map_dss2math_mc_admittance(
    data_dss::Dict{String,<:Any};
    dss2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
    dss2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=true,
    make_pu_extentions::Vector{<:Function}=Function[],
    global_keys::Set{String}=Set{String}(),
    build_model::Bool=false,
    kwargs...,
    )::Dict{String,Any}

    _data_dss = deepcopy(data_dss)

    # _PMD.add_base_voltages!(_data_dss; overwrite=false)

    basemva = 1
    _settings = Dict("sbase_default" => basemva * 1e3,
                "voltage_scale_factor" => 1e3,
                "power_scale_factor" => 1e3,
                "base_frequency" => get(_data_dss, "BaseFrequency", 60.0),
                "vbases_default" => Dict{String,Real}(),
    )

    # any pre-processing of data here

    # TODO kron

    # TODO phase projection

    if ismultinetwork(data_dss)
        #  TODO multi network
    else
        data_math = Dict{String,Any}(
            "name" => get(_data_dss, "name", ""),
            "per_unit" => get(_data_dss, "per_unit", false),
            "data_model" => _PMD.MATHEMATICAL,
            "is_projected" => get(_data_dss, "is_projected", false),
            "is_kron_reduced" => get(_data_dss, "is_kron_reduced", false),
            "settings" => deepcopy(_settings),
            "time_elapsed" => get(_data_dss, "time_elapsed", 1.0),
        )
    end
    data_math["controls"] = Dict{String, Any}()

    _PMD.apply_pmd!(_map_dss2math_nw!, data_math, _data_dss; dss2math_passthrough=dss2math_passthrough, dss2math_extensions=dss2math_extensions)

    return data_math
end


function _map_dss2math_nw!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; dss2math_passthrough::Dict{String,Vector{String}}=Dict{String,Vector{String}}(), dss2math_extensions::Vector{<:Function}=Function[], nw::Int=nw_id_default)
    # need to add mn support
    data_math["map"] = Vector{Dict{String,Any}}([
        Dict{String,Any}("unmap_function" => "_map_math2eng_root!")
    ])

    _PMD._init_base_components!(data_math)

    for property in get(dss2math_passthrough, "root", String[])
        if haskey(data_dss, property)
            data_math[property] = deepcopy(data_dss[property])
        end
    end

    for type in pmp_dss_asset_types
        getfield(PowerModelsProtection, Symbol("_map_dss2math_pmp_$(type)!"))(data_math, data_dss; pass_props=get(dss2math_passthrough, type, String[]))
    end

    # Custom dss2math transformation functions
    for dss2math_func! in dss2math_extensions
        dss2math_func!(data_math, data_dss)
    end

    _PMD.find_conductor_ids!(data_math)
    _pmp_map_conductor_ids!(data_math)
    _PMD._map_settings_vbases_default!(data_math)
    populate_bus_voltages!(data_math)
    fix_voltages!(data_math)

end


function _map_dss2math_pmp_bus!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_eng2math_bus!(data_math, data_dss; pass_props,)
end


function _map_dss2math_pmp_line!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_eng2math_line!(data_math, data_dss; pass_props,)
end


function _map_dss2math_pmp_load!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_eng2math_load!(data_math, data_dss; pass_props,)
    for (i, load) in data_math["load"]
        if !(haskey(load, "vlowpu"))
            load["vlowpu"] =  .50
        end
        if !(haskey(load, "vmaxpu"))
            load["vmaxpu"] =  1.05
        end
        load["i_last"] = zeros(Complex{Float64}, 1, length(load["connections"]))
        if load["model"] == _PMD.POWER
            load["response"] = ConstantPQ
        elseif load["model"] == _PMD.IMPEDANCE
            load["response"] = ConstantZ
        elseif load["model"] == _PMD.CURRENT
            load["response"] = ConstantI
        end
        load["pid"] = Dict{String,Any}(
            "p" => Dict{String,Any}(
                "gain" => 0.0,
                "last" => zeros(Complex{Float64}, 1, length(load["connections"])),
            ),
            "i" => Dict{String,Any}(
                "gain" => 1.0,
                "last" => zeros(Complex{Float64}, 1, length(load["connections"])),
            ),
            "d" => Dict{String,Any}(
                "gain" => 0.0,
                "last" => zeros(Complex{Float64}, 1, length(load["connections"])),
            ),
        )
        load["i_inj"] = zeros(Complex{Float64}, 1, length(load["connections"]))
    end  
end


function _map_dss2math_pmp_shunt!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_eng2math_shunt!(data_math, data_dss; pass_props,)
end


function _map_dss2math_pmp_generator!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_eng2math_generator!(data_math, data_dss; pass_props,)
    for (name, gen) in data_math["gen"]
        if haskey(gen["dss"], "kv")
            kv = parse(Float64, gen["dss"]["kv"])
            gen["vnom_kv"] = fill(kv, length(gen["pg"]))
        end
        if occursin("generator.", gen["source_id"])
            gen["admit_model"] = RotatingMachineElement
            zbase = (gen["vnom_kv"][1] * data_math["settings"]["voltage_scale_factor"])^2/(abs(gen["pmax"][1] + 1im*gen["qmax"][1]) *data_math["settings"]["power_scale_factor"])
            if gen["model"] == 2
                if !haskey(gen, "xp")
                    gen["xp"] = 1.0 * zbase
                end
                if !haskey(gen, "xdp")
                    gen["xdp"] = .27 * zbase
                end
                if !haskey(gen, "xdpp")
                    gen["xdpp"] = .20 * zbase
                end
            end
        end
    end
end


function _map_dss2math_pmp_solar!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_eng2math_solar!(data_math, data_dss; pass_props,)
     for (name, gen) in data_math["gen"]
        if occursin("solar.", gen["source_id"])
            gen["grid_forming"] = false
            gen["admit_model"] = PVSystemElement
            4 in gen["connections"] ? gen["phases"] = length(gen["connections"]) - 1 : gen["phases"] = length(gen["connections"])
            haskey(gen["dss"], "balanced") ? gen["balanced"] = gen["dss"]["balanced"] : gen["balanced"] = true
            haskey(gen["dss"], "vminpu") ? gen["vminpu"] = parse(Float64, gen["dss"]["vminpu"]) : gen["vminpu"] = 1/1.5
            irated = abs(gen["pmax"][1] + 1im * gen["qmax"][1]) * data_math["settings"]["power_scale_factor"] / (gen["vg"][1] * data_math["settings"]["voltage_scale_factor"])
            gen["imax"] = irated * 1/gen["vminpu"]
            gen["i_last"] = zeros(Complex{Float64}, gen["phases"], 1)
        end
    end
end

function _map_dss2math_pmp_storage!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    # _PMD._map_dss2math_load!(data_math, data_dss; pass_props,)
end


function _map_dss2math_pmp_transformer!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    "alternate to pmd transformer TODO work on 3 winding"
    for (name, dss_obj) in get(data_dss, "transformer", Dict{Any,Dict{String,Any}}())
        pop!(dss_obj, "bank1", nothing)
        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => String[],
            "unmap_function" => "_map_math2eng_transformer!",
        ))

        to_map = data_math["map"][end]["to"]

        _PMD._apply_xfmrcode!(dss_obj, data_dss)

        if haskey(dss_obj, "f_bus") && haskey(dss_obj, "t_bus")
            @assert all(haskey(dss_obj, k) for k in ["f_bus", "t_bus", "f_connections", "t_connections"]) "Incomplete definition of AL2W tranformer $name, aborting eng2math conversion"

            nphases = length(dss_obj["f_connections"])

            math_obj = Dict{String,Any}(
                "name" => name,
                "source_id" => dss_obj["source_id"],
                "f_bus" => data_math["bus_lookup"][dss_obj["f_bus"]],
                "t_bus" => data_math["bus_lookup"][dss_obj["t_bus"]],
                "f_connections" => dss_obj["f_connections"],
                "t_connections" => dss_obj["t_connections"],
                "configuration" => get(dss_obj, "configuration", _PMD.WYE),
                "tm_nom" => get(dss_obj, "tm_nom", 1.0),
                "tm_set" => get(dss_obj, "tm_set", fill(1.0, nphases)),
                "tm_fix" => get(dss_obj, "tm_fix", fill(true, nphases)),
                "polarity" => get(dss_obj, "polarity", -1),
                "sm_ub" => get(dss_obj, "sm_ub", Inf),
                "cm_ub" => get(dss_obj, "cm_ub", Inf),
                "status" => Int(get(dss_obj, "status", ENABLED)),
                "index" => length(data_math["transformer"]) + 1,
                "dss" => dss_obj["dss"]
            )

            for k in [["tm_lb", "tm_ub"]; pass_props]
                if haskey(dss_obj, k)
                    math_obj[k] = dss_obj[k]
                end
            end

            4 in dss_obj["f_connections"] ? math_obj["phases"] = length(dss_obj["f_connections"]) - 1 : math_obj["phases"] = length(dss_obj["f_connections"])

            haskey(dss_obj["dss"], "leadlag") ? math_obj["leadLag"] = transformer["dss"]["leadlag"] : math_obj["leadLag"] = "lag"

            data_math["transformer"]["$(math_obj["index"])"] = math_obj

            push!(to_map, "transformer.$(math_obj["index"])")
        else
            vnom = dss_obj["vm_nom"] * data_dss["settings"]["voltage_scale_factor"]
            snom = dss_obj["sm_nom"] * data_dss["settings"]["power_scale_factor"]

            nrw = length(dss_obj["bus"])

            !haskey(dss_obj["dss"], "buses") ? dss_obj["dss"]["buses"] = dss_obj["bus"] : nothing # fix to buses issue missing form dss (single buses are defined on some transformers)

            # calculate zbase in which the data is specified, and convert to SI
            zbase = (vnom .^ 2) ./ snom

            # x_sc is specified with respect to first winding
            x_sc = dss_obj["xsc"] .* zbase[1]

            # rs is specified with respect to each winding
            r_s = dss_obj["rw"] .* zbase

            # want percentage for matrix
            g_sh = dss_obj["noloadloss"]
            b_sh = -dss_obj["cmag"]

            # data is measured externally, but we now refer it to the internal side
            ratios = vnom / data_dss["settings"]["voltage_scale_factor"]
            x_sc = x_sc ./ ratios[1]^2
            r_s = r_s ./ ratios .^ 2
            # g_sh = g_sh*ratios[1]^2
            # b_sh = b_sh*ratios[1]^2

            # convert x_sc from list of upper triangle elements to an explicit dict
            y_sh = g_sh + im * b_sh
            z_sc = Dict([(key, im * x_sc[i]) for (i, key) in enumerate([(i, j) for i in 1:nrw for j in i+1:nrw])])

            dims = length(dss_obj["tm_set"][1])
            tm_nom = dss_obj["vm_nom"]
            # for i = 1:nrw
            #     tm_nom[i] = dss_obj["configuration"][i]==_PMD.DELTA ? dss_obj["vm_nom"][i] : dss_obj["vm_nom"][i]
            #     # tm_nom[i] = dss_obj["configuration"][i]==_PMD.DELTA ? dss_obj["vm_nom"][i]*sqrt(3) : dss_obj["vm_nom"][i]
            # end
            t_connections = sort!(dss_obj["connections"][2])
            t_bus = data_math["bus_lookup"][dss_obj["bus"][2]]
            # 3-w transformers will have vectors: t_bus and t_connections, center_tap will have vectors: t_connections
            # TODO make sure that the connections always coordinate with bus
            if length(dss_obj["connections"]) > 2
                t_connections = [sort!(dss_obj["connections"][2])]
                t_bus = [data_math["bus_lookup"][dss_obj["bus"][2]]]
                for row in dss_obj["connections"][2+1:end]
                    push!(t_connections, sort!(row))
                end
                for bus in dss_obj["bus"][2+1:end]
                    push!(t_bus, data_math["bus_lookup"][bus])
                end
            end

            transformer_obj = Dict{String,Any}(
                "name" => name,
                "source_id" => dss_obj["source_id"],
                "f_bus" => data_math["bus_lookup"][dss_obj["bus"][1]],
                "t_bus" => t_bus,
                "tm_nom" => tm_nom,
                "f_connections" => sort!(dss_obj["connections"][1]),
                "t_connections" => t_connections,
                "configuration" => dss_obj["configuration"],
                "polarity" => dss_obj["polarity"],
                "tm_set" => dss_obj["tm_set"],
                "tm_fix" => dss_obj["tm_fix"],
                "sm_ub" => get(dss_obj, "sm_ub", Inf),
                "cm_ub" => get(dss_obj, "cm_ub", Inf),
                "status" => dss_obj["status"] == DISABLED ? 0 : 1,
                "index" => length(data_math["transformer"]) + 1,
                "x_sc" => x_sc,
                "xsc" => dss_obj["xsc"],
                "r_s" => r_s,
                "rw" => dss_obj["rw"],
                "g_sh" => g_sh,
                "b_sh" => b_sh,
                "dss" => haskey(dss_obj, "dss") ? dss_obj["dss"] : Dict{String,Any}(),
                "sm_nom" => dss_obj["sm_nom"]
            )

            for prop in [["tm_lb", "tm_ub", "tm_step"]; pass_props]
                if haskey(dss_obj, prop)
                    transformer_obj[prop] = dss_obj[prop]
                end
            end
            4 in transformer_obj["f_connections"] ? transformer_obj["phases"] = length(transformer_obj["f_connections"]) - 1 : transformer_obj["phases"] = length(transformer_obj["f_connections"])

            haskey(dss_obj["dss"], "leadlag") ? transformer_obj["leadLag"] = dss_obj["dss"]["leadlag"] : transformer_obj["leadLag"] = "lag"

            transformer_obj["vm_nom"] = [[zeros(1, length(transformer_obj["f_connections"]))] [zeros(1, length(transformer_obj["t_connections"]))]]
            if transformer_obj["phases"] == 1
                transformer_obj["vm_nom"][1][1] = transformer_obj["tm_nom"][1]
                transformer_obj["vm_nom"][2][1] = transformer_obj["tm_nom"][2]
            else
                for (i, _i) in enumerate(transformer_obj["f_connections"])
                    if _i != 4 && _i != 5
                        transformer_obj["vm_nom"][1][i] = transformer_obj["tm_nom"][1]/sqrt(3)
                    end
                end
                for (i, _i) in enumerate(transformer_obj["t_connections"])
                    if _i != 4 && _i != 5
                        transformer_obj["vm_nom"][2][i] = transformer_obj["tm_nom"][2]/sqrt(3)
                    end
                end
            end
       
            data_math["transformer"]["$(transformer_obj["index"])"] = transformer_obj
   
            if haskey(dss_obj,"controls") #&& !all(data_math["transformer"]["$(transformer_2wa_obj["index"])"]["tm_fix"])
                reg_obj = Dict{String,Any}(
                    "vreg" => dss_obj["controls"]["vreg"],
                    "band" => dss_obj["controls"]["band"],
                    "ptratio" => dss_obj["controls"]["ptratio"],
                    "ctprim" => dss_obj["controls"]["ctprim"],
                    "r" => dss_obj["controls"]["r"],
                    "x" => dss_obj["controls"]["x"],
                )
                data_math["transformer"]["$(transformer_obj["index"])"]["controls"] = reg_obj
                if !(haskey(data_math["controls"], "transformer"))
                    data_math["controls"]["transformer"] = Dict{String, Any}()
                end
                data_math["controls"]["transformer"]["$(transformer_obj["index"])"] = "reg"
            end
        end
    end
end


function _map_dss2math_pmp_switch!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)   
    for (name, dss_obj) in get(data_dss, "switch", Dict{Any,Dict{String,Any}}())

        nphases = length(dss_obj["f_connections"])

        math_obj = _PMD._init_math_obj("switch", name, dss_obj, length(data_math["switch"]) + 1; pass_props=pass_props)

        math_obj["f_bus"] = data_math["bus_lookup"][dss_obj["f_bus"]]
        math_obj["t_bus"] = data_math["bus_lookup"][dss_obj["t_bus"]]
        math_obj["status"] = dss_obj["status"] == _PMD.DISABLED ? 0 : 1

        math_obj["state"] = Int(get(dss_obj, "state", _PMD.CLOSED))
        math_obj["dispatchable"] = Int(get(dss_obj, "dispatchable", _PMD.YES))

        # OPF bounds
        for (f_key, t_key) in [("cm_ub", "current_rating"), ("cm_ub_b", "c_rating_b"), ("cm_ub_c", "c_rating_c"),
            ("sm_ub", "thermal_rating"), ("sm_ub_b", "rate_b"), ("sm_ub_c", "rate_c")]
            math_obj[t_key] = haskey(dss_obj, f_key) ? dss_obj[f_key] : fill(Inf, nphases)
        end

        map_to = "switch.$(math_obj["index"])"

        if haskey(dss_obj, "linecode")
            _PMD._apply_linecode!(dss_obj, data_dss)
        end
        
        math_obj["br_r"] = _PMD._impedance_conversion(data_dss, dss_obj, "rs")
        math_obj["br_x"] = _PMD._impedance_conversion(data_dss, dss_obj, "xs")
        math_obj["g_fr"] = zeros(nphases, nphases)
        math_obj["g_to"] = zeros(nphases, nphases)
        math_obj["b_fr"] = zeros(nphases, nphases)
        math_obj["b_to"] = zeros(nphases, nphases)

        data_math["switch"]["$(math_obj["index"])"] = math_obj

        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => map_to,
            "unmap_function" => "_map_math2eng_switch!",
        ))
    end
end


function _map_dss2math_pmp_voltage_source!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    for (name, dss_obj) in get(data_dss, "voltage_source", Dict{String,Any}())

        nconductors = length(dss_obj["connections"])
        nphases = get(dss_obj, "configuration", _PMD.WYE) == _PMD.WYE && !get(data_dss, "is_kron_reduced", false) ? nconductors - 1 : nconductors

        math_obj = _PMD._init_math_obj("voltage_source", name, dss_obj, length(data_math["gen"]) + 1; pass_props=pass_props)

        math_obj["name"] = name
        math_obj["gen_bus"] = gen_bus = data_math["bus_lookup"][dss_obj["bus"]]
        math_obj["connections"] = dss_obj["connections"]
        math_obj["gen_status"] = status = Int(dss_obj["status"])
        math_obj["pg"] = get(dss_obj, "pg", fill(0.0, nphases))
        math_obj["qg"] = get(dss_obj, "qg", fill(0.0, nphases))
        math_obj["vg"] = dss_obj["vm"]
        math_obj["pmin"] = get(dss_obj, "pg_lb", fill(-Inf, nphases))
        math_obj["pmax"] = get(dss_obj, "pg_ub", fill(Inf, nphases))
        math_obj["qmin"] = get(dss_obj, "qg_lb", fill(-Inf, nphases))
        math_obj["qmax"] = get(dss_obj, "qg_ub", fill(Inf, nphases))
        math_obj["connections"] = dss_obj["connections"]
        math_obj["configuration"] = get(dss_obj, "configuration", _PMD.WYE)
        math_obj["control_mode"] = control_mode = Int(get(dss_obj, "control_mode", _PMD.ISOCHRONOUS))
        math_obj["source_id"] = "voltage_source.$name"
        math_obj["rs"] = dss_obj["rs"]
        math_obj["xs"] = dss_obj["xs"]

        _PMD._add_gen_cost_model!(math_obj, dss_obj)
        math_obj["admit_model"] = VoltageSourceElement

        bus_obj = data_math["bus"]["$gen_bus"]
        bus_obj["vm"] = deepcopy(dss_obj["vm"])
        bus_obj["va"] = deepcopy(dss_obj["va"])
        bus_obj["bus_type"] = status == 0 ? 4 : 3

        if !all(isapprox.(get(dss_obj, "rs", zeros(1, 1)), 0)) && !all(isapprox.(get(dss_obj, "xs", zeros(1, 1)), 0))

            for (i, t) in enumerate(dss_obj["connections"])
                if data_math["bus"]["$(data_math["bus_lookup"][dss_obj["bus"]])"]["grounded"][i]
                    bus_obj["vm"][i] = 0
                    bus_obj["vmin"][i] = 0
                    bus_obj["vmax"][i] = Inf
                end
            end

        else
            vm_lb = control_mode == Int(_PMD.ISOCHRONOUS) ? dss_obj["vm"] : get(dss_obj, "vm_lb", fill(0.0, nphases))
            vm_ub = control_mode == Int(_PMD.ISOCHRONOUS) ? dss_obj["vm"] : get(dss_obj, "vm_ub", fill(Inf, nphases))

            data_math["bus"]["$gen_bus"]["vmin"] = [vm_lb..., [0.0 for n in 1:(nconductors-nphases)]...]
            data_math["bus"]["$gen_bus"]["vmax"] = [vm_ub..., [Inf for n in 1:(nconductors-nphases)]...]
            data_math["bus"]["$gen_bus"]["vm"] = [dss_obj["vm"]..., [0.0 for n in 1:(nconductors-nphases)]...]
            data_math["bus"]["$gen_bus"]["va"] = [dss_obj["va"]..., [0.0 for n in 1:(nconductors-nphases)]...]

            bus_type = data_math["bus"]["$gen_bus"]["bus_type"]
            data_math["bus"]["$gen_bus"]["bus_type"] = _PMD._compute_bus_type(bus_type, status, control_mode)
        end

        4 in math_obj["connections"] ? math_obj["phases"] = length(math_obj["connections"]) - 1 : math_obj["phases"] = length(math_obj["connections"])
            
        data_math["gen"]["$(math_obj["index"])"] = math_obj

    end
end


function transform_data_model_mc_(
    data::Dict{String,<:Any};
    global_keys::Set{String}=Set{String}(),
    eng2math_passthrough::Dict{String,<:Vector{<:String}}=_pmp_eng2math_passthrough,
    eng2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=true,
    make_pu_extensions::Vector{<:Function}=Function[],
    build_model::Bool=false,
    correct_network_data::Bool=true,
    kwargs...,
    )::Dict{String,Any}

    if data["method"] == "PM"
        # TODO work on transmission admittance model
    elseif data["method"] == "PMD"
        data_math = _map_eng2math_mc_admittance(
            data;
            eng2math_extensions=[_eng2math_link_transformer, eng2math_extensions...],
            # eng2math_extensions = [_eng2math_gen_model!], # TODO concat eng2math_extensions
            eng2math_passthrough=eng2math_passthrough,
            make_pu_extensions=make_pu_extensions,
            global_keys=global_keys,
            build_model=build_model,
            kwargs...
        )

        correct_network_data && correct_network_data!(data_math)

        correct_grounds!(data_math)

        populate_bus_voltages!(data_math)

        add_mc_last_current_keys!(data_math)

        return data_math
    end
end



"custom version of 'transform_data_model' to build admittance model and deal with transformers"
function transform_admittance_data_model(
    data::Dict{String,<:Any};
    global_keys::Set{String}=Set{String}(),
    eng2math_passthrough::Dict{String,<:Vector{<:String}}=_pmp_eng2math_passthrough,
    eng2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=true,
    make_pu_extensions::Vector{<:Function}=Function[],
    build_model::Bool=false,
    correct_network_data::Bool=true,
    kwargs...,
    )::Dict{String,Any}

    if data["method"] == "PM"
        # TODO work on transmission admittance model
    elseif data["method"] == "PMD"
        data_math = _map_eng2math_mc_admittance(
            data;
            eng2math_extensions=[_eng2math_link_transformer, eng2math_extensions...],
            # eng2math_extensions = [_eng2math_gen_model!], # TODO concat eng2math_extensions
            eng2math_passthrough=eng2math_passthrough,
            make_pu_extensions=make_pu_extensions,
            global_keys=global_keys,
            build_model=build_model,
            kwargs...
        )

        correct_network_data && correct_network_data!(data_math)

        correct_grounds!(data_math)

        populate_bus_voltages!(data_math)

        add_mc_last_current_keys!(data_math)

        return data_math
    end
end


# "base function for converting mc engineering model to mathematical with admittances"
# function _map_eng2math_mc_admittance(
#     data_dss::Dict{String,<:Any};
#     eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
#     eng2math_extensions::Vector{<:Function}=Function[],
#     make_pu::Bool=true,
#     make_pu_extentions::Vector{<:Function}=Function[],
#     global_keys::Set{String}=Set{String}(),
#     build_model::Bool=false,
#     kwargs...,
# )::Dict{String,Any}

#     _data_dss = deepcopy(data_dss)

#     # any pre-processing of data here

#     # TODO kron

#     # TODO phase projection

#     if ismultinetwork(data_dss)
#         #  TODO multi network
#     else
#         data_math = Dict{String,Any}(
#             "name" => get(_data_dss, "name", ""),
#             "per_unit" => get(_data_dss, "per_unit", false),
#             "data_model" => _PMD.MATHEMATICAL,
#             "is_projected" => get(_data_dss, "is_projected", false),
#             "is_kron_reduced" => get(_data_dss, "is_kron_reduced", false),
#             "settings" => deepcopy(_data_dss["settings"]),
#             "time_elapsed" => get(_data_dss, "time_elapsed", 1.0),
#         )
#     end
#     data_math["controls"] = Dict{String, Any}()
    
#     _map_eng2math_nw!(data_math, data_dss, eng2math_passthrough=eng2math_passthrough, eng2math_extensions=eng2math_extensions)

#     _apply_mc_admittance!(_map_eng2math_mc_admittance_nw!, data_math, _data_dss; eng2math_passthrough=eng2math_passthrough, eng2math_extensions=eng2math_extensions)

#     # admittance_bus_order!(data_math)
#     return data_math
# end


# # function _apply_mc_admittance!(func!::Function, data1::Dict{String,<:Any}, data2::Dict{String,<:Any}; kwargs...)
# #     func!(data1, data2; kwargs...)
# # end


# function _map_eng2math_mc_admittance_nw!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(), eng2math_extensions::Vector{<:Function}=Function[])
#     for type in _mc_admittance_asset_types # --> anything from missing from the model needed for the solve or admittance matrix maybe per unit to actual
#         getfield(PowerModelsProtection, Symbol("_map_eng2math_mc_admittance_$(type)!"))(data_math, data_dss; pass_props=get(eng2math_passthrough, type, String[]))
#     end
# end


# "mod with out per unit corrections see: common.jl in io PowerModelsDistribution"
function correct_network_data!(data::Dict{String,Any})
    if _PMD.iseng(data)
        _PMD.check_eng_data_model(data)
    elseif _PMD.ismath(data)
        nothing
        # check_connectivity(data) not done here becuase checks are performed during admittance creation

        # correct_branch_directions!(data) used to tell if parallel lines are in same direction
        # check_branch_loops(data) ill add check in admit creation

        # correct_bus_types!(data) check for islands, slack and no slack and fixes. will need to add TODO

        #  TODO propagate_network_topology!(data) need to add chck for it

        #  no pu
        # if make_pu
        #     make_per_unit!(data; make_pu_extensions=make_pu_extensions)

        #     correct_mc_voltage_angle_differences!(data)
        #     correct_mc_thermal_limits!(data)

        #     correct_cost_functions!(data)
        #     standardize_cost_terms!(data)
        # end
    end
end

# function populate_bus_voltages!(data::Dict{String,Any})
#     for (i, transformer) in data["transformer"]
#         f_bus = transformer["f_bus"]
#         t_bus = transformer["t_bus"]
#         if haskey(transformer, "tm_nom")
#             transformer["phases"] == 3 ? multi = 1 / sqrt(3) : multi = 1
#             if !haskey(data["bus"][string(f_bus)], "vbase")
#                 data["bus"][string(f_bus)]["vbase"] = transformer["tm_nom"][1] * multi
#             end
#             # Vector{Vector{Int}}
#             if typeof(t_bus) == Vector{Int64}
#                 for (indx, bus) in enumerate(t_bus)
#                     if !haskey(data["bus"][string(bus)], "vbase")
#                         data["bus"][string(bus)]["vbase"] = transformer["tm_nom"][indx+1] * multi
#                     end
#                 end
#             else
#                 if !haskey(data["bus"][string(t_bus)], "vbase")
#                     data["bus"][string(t_bus)]["vbase"] = transformer["tm_nom"][2] * multi
#                 end
#             end
#         end
#     end

#     propagate_voltages!(data)

#     for (i, gen) in data["gen"]
#         if !haskey(data["bus"][string(gen["gen_bus"])], "vbase")
#             # if gen["element"] == VoltageSourceElement
#             if gen["model_type"] == "pv_systems"
#                 data["bus"][string(gen["gen_bus"])]["vbase"] = gen["vg"][1]
#             end
#         end
#     end
#     propagate_voltages!(data)

# end


# function propagate_voltages!(data::Dict{String,Any})
#     buses = collect(keys(data["bus"]))
#     for (i, bus) in data["bus"]
#         !haskey(bus, "vbase") ? filter!(n -> n != string(i), buses) : nothing
#     end

#     found = true
#     while found
#         found = false
#         for (i, branch) in data["branch"]
#             f_bus = string(branch["f_bus"])
#             t_bus = string(branch["t_bus"])
#             if f_bus in buses
#                 if t_bus in buses
#                     nothing
#                 else
#                     data["bus"][t_bus]["vbase"] = data["bus"][f_bus]["vbase"]
#                     found = true
#                     push!(buses, t_bus)
#                 end
#             elseif t_bus in buses
#                 if f_bus in buses
#                     nothing
#                 else
#                     data["bus"][f_bus]["vbase"] = data["bus"][t_bus]["vbase"]
#                     found = true
#                     push!(buses, f_bus)
#                 end
#             end
#         end
#     end
# end


function correct_grounds!(data::Dict{String,Any})
    for (i, transformer) in data["transformer"]
        # println(data["bus"][string(transformer["t_bus"])])
        # for (i, config) in enumerate(transformer["configuration"])
        #     if config == _PMD.WYE
        #         println(transformer["dss"]["buses"])
        #         buses = isa(transformer["dss"]["buses"], String) ? split(transformer["dss"]["buses"]) : transformer["dss"]["buses"]
        #         println(buses)
        #         if occursin(".1.2.3.0", buses[i])
        #             if i == 2
        #                 transformer["t_connections"] = [1, 2, 3, 4]
        #                 data["bus"][string(transformer["t_bus"])]["terminals"] = [1, 2, 3, 4]
        #                 data["bus"][string(transformer["t_bus"])]["grounded"] = Bool[0, 0, 0, 1]
        #             end
        #         end
        #     end
        # end
    end
end

