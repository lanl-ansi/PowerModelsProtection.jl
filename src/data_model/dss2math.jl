

"field/values to passthrough from the ENGINEERING to MATHEMATICAL data models"
const _pmp_dss2math_passthrough = Dict{String,Vector{String}}(
        "generator" => String["zr", "zx", "gen_model", "xdp", "rp", "xdpp", "vnom_kv", "phases", "response", "element"],
        "solar" => String["i_max", "solar_max", "kva", "pf", "grid_forming", "balanced", "vminpu", "transformer", "type", "pv_model", "phases", "response", "element", "fault_model", "i_nom", "i+", "i-", "p_control"],
        "voltage_source" => String["zr", "zx", "phases", "response", "element"],
        "load" => String["vminpu", "vmaxpu", "response", "phases", "element"],
        "transformer" => String["leadlag", "phases", "element"]
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


# "admittance model"
# const _mc_admittance_asset_types = [
#     "line", "voltage_source", "load", "transformer", "shunt", "solar", "generator"
# ]

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

        correct_network_data && correct_network_data!(data_math)

        correct_grounds!(data_math)

        populate_bus_voltages!(data_math)

        add_mc_last_current_keys!(data_math)

        return data_math
end


function _map_dss2math_mc_admittance(
    data_dsss::Dict{String,<:Any};
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
                "base_frequency" => get(_data_ravens, "BaseFrequency", 60.0),
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
        getfield(PowerModelsProtection, Symbol("_map_ravens2math_pmp_$(type)!"))(data_math, data_ravens; pass_props=get(ravens2math_passthrough, type, String[]))
    end

    # Custom ravens2math transformation functions
    for ravens2math_func! in ravens2math_extensions
        ravens2math_func!(data_math, data_ravens)
    end

    _PMD.find_conductor_ids!(data_math)
    _pmp_map_conductor_ids!(data_math)
    _PMD._map_settings_vbases_default!(data_math)

end


function _map_ravens2math_pmp_line!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_eng2math_line!(data_math, data_dss; pass_props,)
end


function _map_ravens2math_pmp_load!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_load!(data_math, data_dss; pass_props,)
end


function _map_ravens2math_pmp_shunt!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_load!(data_math, data_ravens; pass_props,)
end


function _map_ravens2math_pmp_generator!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_load!(data_math, data_ravens; pass_props,)
end


function _map_ravens2math_pmp_solar!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_load!(data_math, data_ravens; pass_props,)
end

function _map_ravens2math_pmp_storage!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_load!(data_math, data_ravens; pass_props,)
end


function _map_dss2math_pmp_transformer!(data_math::Dict{String,<:Any}, data_dss::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    "alternate to pmd transformer TODO work on 3 winding"
    for (name, eng_obj) in get(data_eng, "transformer", Dict{Any,Dict{String,Any}}())
        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => String[],
            "unmap_function" => "_map_math2eng_transformer!",
        ))

        to_map = data_math["map"][end]["to"]

        _PMD._apply_xfmrcode!(eng_obj, data_eng)

        if haskey(eng_obj, "f_bus") && haskey(eng_obj, "t_bus")
            @assert all(haskey(eng_obj, k) for k in ["f_bus", "t_bus", "f_connections", "t_connections"]) "Incomplete definition of AL2W tranformer $name, aborting eng2math conversion"

            nphases = length(eng_obj["f_connections"])

            math_obj = Dict{String,Any}(
                "name" => name,
                "source_id" => eng_obj["source_id"],
                "f_bus" => data_math["bus_lookup"][eng_obj["f_bus"]],
                "t_bus" => data_math["bus_lookup"][eng_obj["t_bus"]],
                "f_connections" => eng_obj["f_connections"],
                "t_connections" => eng_obj["t_connections"],
                "configuration" => get(eng_obj, "configuration", _PMD.WYE),
                "tm_nom" => get(eng_obj, "tm_nom", 1.0),
                "tm_set" => get(eng_obj, "tm_set", fill(1.0, nphases)),
                "tm_fix" => get(eng_obj, "tm_fix", fill(true, nphases)),
                "polarity" => get(eng_obj, "polarity", -1),
                "sm_ub" => get(eng_obj, "sm_ub", Inf),
                "cm_ub" => get(eng_obj, "cm_ub", Inf),
                "status" => Int(get(eng_obj, "status", ENABLED)),
                "index" => length(data_math["transformer"]) + 1,
                "dss" => eng_obj["dss"]
            )

            for k in [["tm_lb", "tm_ub"]; pass_props]
                if haskey(eng_obj, k)
                    math_obj[k] = eng_obj[k]
                end
            end

            data_math["transformer"]["$(math_obj["index"])"] = math_obj

            push!(to_map, "transformer.$(math_obj["index"])")
        else
            vnom = eng_obj["vm_nom"] * data_eng["settings"]["voltage_scale_factor"]
            snom = eng_obj["sm_nom"] * data_eng["settings"]["power_scale_factor"]

            nrw = length(eng_obj["bus"])

            !haskey(eng_obj["dss"], "buses") ? eng_obj["dss"]["buses"] = eng_obj["bus"] : nothing # fix to buses issue missing form dss (single buses are defined on some transformers)

            # calculate zbase in which the data is specified, and convert to SI
            zbase = (vnom .^ 2) ./ snom

            # x_sc is specified with respect to first winding
            x_sc = eng_obj["xsc"] .* zbase[1]

            # rs is specified with respect to each winding
            r_s = eng_obj["rw"] .* zbase

            # want percentage for matrix
            g_sh = eng_obj["noloadloss"]
            b_sh = -eng_obj["cmag"]

            # data is measured externally, but we now refer it to the internal side
            ratios = vnom / data_eng["settings"]["voltage_scale_factor"]
            x_sc = x_sc ./ ratios[1]^2
            r_s = r_s ./ ratios .^ 2
            # g_sh = g_sh*ratios[1]^2
            # b_sh = b_sh*ratios[1]^2

            # convert x_sc from list of upper triangle elements to an explicit dict
            y_sh = g_sh + im * b_sh
            z_sc = Dict([(key, im * x_sc[i]) for (i, key) in enumerate([(i, j) for i in 1:nrw for j in i+1:nrw])])

            dims = length(eng_obj["tm_set"][1])
            tm_nom = eng_obj["vm_nom"]
            # for i = 1:nrw
            #     tm_nom[i] = eng_obj["configuration"][i]==_PMD.DELTA ? eng_obj["vm_nom"][i] : eng_obj["vm_nom"][i]
            #     # tm_nom[i] = eng_obj["configuration"][i]==_PMD.DELTA ? eng_obj["vm_nom"][i]*sqrt(3) : eng_obj["vm_nom"][i]
            # end
            t_connections = sort!(eng_obj["connections"][2])
            t_bus = data_math["bus_lookup"][eng_obj["bus"][2]]
            # 3-w transformers will have vectors: t_bus and t_connections, center_tap will have vectors: t_connections
            # TODO make sure that the connections always coordinate with bus
            if length(eng_obj["connections"]) > 2
                t_connections = [sort!(eng_obj["connections"][2])]
                t_bus = [data_math["bus_lookup"][eng_obj["bus"][2]]]
                for row in eng_obj["connections"][2+1:end]
                    push!(t_connections, sort!(row))
                end
                for bus in eng_obj["bus"][2+1:end]
                    push!(t_bus, data_math["bus_lookup"][bus])
                end
            end

            transformer_obj = Dict{String,Any}(
                "name" => name,
                "source_id" => eng_obj["source_id"],
                "f_bus" => data_math["bus_lookup"][eng_obj["bus"][1]],
                "t_bus" => t_bus,
                "tm_nom" => tm_nom,
                "f_connections" => sort!(eng_obj["connections"][1]),
                "t_connections" => t_connections,
                "configuration" => eng_obj["configuration"],
                "polarity" => eng_obj["polarity"],
                "tm_set" => eng_obj["tm_set"],
                "tm_fix" => eng_obj["tm_fix"],
                "sm_ub" => get(eng_obj, "sm_ub", Inf),
                "cm_ub" => get(eng_obj, "cm_ub", Inf),
                "status" => eng_obj["status"] == DISABLED ? 0 : 1,
                "index" => length(data_math["transformer"]) + 1,
                "x_sc" => x_sc,
                "xsc" => eng_obj["xsc"],
                "r_s" => r_s,
                "rw" => eng_obj["rw"],
                "g_sh" => g_sh,
                "b_sh" => b_sh,
                "dss" => haskey(eng_obj, "dss") ? eng_obj["dss"] : Dict{String,Any}(),
                "sm_nom" => eng_obj["sm_nom"]
            )

            for prop in [["tm_lb", "tm_ub", "tm_step"]; pass_props]
                if haskey(eng_obj, prop)
                    transformer_obj[prop] = eng_obj[prop]
                end
            end


            phases = isa(transformer_obj["dss"]["phases"], String) ? parse(Int, transformer_obj["dss"]["phases"]) : transformer_obj["dss"]["phases"]
            if haskey(transformer_obj, "vm_nom")
                if phases == 3
                    data_math["bus"][string(transformer_obj["f_bus"])]["vbase"] = transformer_obj["vm_nom"][1] / sqrt(3)
                    data_math["bus"][string(transformer_obj["t_bus"])]["vbase"] = transformer_obj["vm_nom"][2:end] ./ sqrt(3)
                else
                    data_math["bus"][string(transformer_obj["f_bus"])]["vbase"] = transformer_obj["vm_nom"][1]
                    data_math["bus"][string(transformer_obj["t_bus"])]["vbase"] = transformer_obj["vm_nom"][2:end]
                end
            end

            data_math["transformer"]["$(transformer_obj["index"])"] = transformer_obj
   
            if haskey(eng_obj,"controls") #&& !all(data_math["transformer"]["$(transformer_2wa_obj["index"])"]["tm_fix"])
                reg_obj = Dict{String,Any}(
                    "vreg" => eng_obj["controls"]["vreg"],
                    "band" => eng_obj["controls"]["band"],
                    "ptratio" => eng_obj["controls"]["ptratio"],
                    "ctprim" => eng_obj["controls"]["ctprim"],
                    "r" => eng_obj["controls"]["r"],
                    "x" => eng_obj["controls"]["x"],
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
            _PMD._apply_linecode!(dss_obj, data_eng)
        end
        # TODO more test and define perfect
        if !(all(isapprox.(get(dss_obj, "rs", zeros(1, 1)), 0)) && all(isapprox.(get(dss_obj, "xs", zeros(1, 1)), 0)))

            f_bus = data_math["bus_lookup"][dss_obj["f_bus"]]
            t_bus = data_math["bus_lookup"][dss_obj["t_bus"]]

            N = length(dss_obj["t_connections"])


            branch_obj = _PMD._init_math_obj("line", name, dss_obj, length(data_math["branch"]) + 1)

            _branch_obj = Dict{String,Any}(
                "name" => "_virtual_branch.switch.$name",
                "source_id" => "switch.$name",
                "f_bus" => f_bus,
                "t_bus" => t_bus,
                "f_connections" => dss_obj["t_connections"],  # the virtual branch connects to the switch on the to-side
                "t_connections" => dss_obj["t_connections"],  # should be identical to the switch's to-side connections
                "br_r" => _PMD._impedance_conversion(data_eng, dss_obj, "rs"),
                "br_x" => _PMD._impedance_conversion(data_eng, dss_obj, "xs"),
                "g_fr" => zeros(nphases, nphases),
                "g_to" => zeros(nphases, nphases),
                "b_fr" => zeros(nphases, nphases),
                "b_to" => zeros(nphases, nphases),
                "angmin" => fill(-10.0, nphases),
                "angmax" => fill(10.0, nphases),
                "c_rating_a" => fill(Inf, nphases),
                "br_status" => dss_obj["status"] == _PMD.DISABLED ? 0 : 1,
            )

            merge!(branch_obj, _branch_obj)

            data_math["branch"]["$(branch_obj["index"])"] = branch_obj

        end

        data_math["switch"]["$(math_obj["index"])"] = math_obj

        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => map_to,
            "unmap_function" => "_map_math2eng_switch!",
        ))
    end
end


function _map_ravens2math_pmp_voltage_source!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_switch!(data_math, data_ravens; pass_props,)
    gfgffggf
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


"base function for converting mc engineering model to mathematical with admittances"
function _map_eng2math_mc_admittance(
    data_eng::Dict{String,<:Any};
    eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
    eng2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=true,
    make_pu_extentions::Vector{<:Function}=Function[],
    global_keys::Set{String}=Set{String}(),
    build_model::Bool=false,
    kwargs...,
)::Dict{String,Any}

    _data_eng = deepcopy(data_eng)

    # any pre-processing of data here

    # TODO kron

    # TODO phase projection

    if ismultinetwork(data_eng)
        #  TODO multi network
    else
        data_math = Dict{String,Any}(
            "name" => get(_data_eng, "name", ""),
            "per_unit" => get(_data_eng, "per_unit", false),
            "data_model" => _PMD.MATHEMATICAL,
            "is_projected" => get(_data_eng, "is_projected", false),
            "is_kron_reduced" => get(_data_eng, "is_kron_reduced", false),
            "settings" => deepcopy(_data_eng["settings"]),
            "time_elapsed" => get(_data_eng, "time_elapsed", 1.0),
        )
    end
    data_math["controls"] = Dict{String, Any}()
    
    _map_eng2math_nw!(data_math, data_eng, eng2math_passthrough=eng2math_passthrough, eng2math_extensions=eng2math_extensions)

    _apply_mc_admittance!(_map_eng2math_mc_admittance_nw!, data_math, _data_eng; eng2math_passthrough=eng2math_passthrough, eng2math_extensions=eng2math_extensions)

    # admittance_bus_order!(data_math)
    return data_math
end


# function _apply_mc_admittance!(func!::Function, data1::Dict{String,<:Any}, data2::Dict{String,<:Any}; kwargs...)
#     func!(data1, data2; kwargs...)
# end


function _map_eng2math_mc_admittance_nw!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(), eng2math_extensions::Vector{<:Function}=Function[])
    for type in _mc_admittance_asset_types # --> anything from missing from the model needed for the solve or admittance matrix maybe per unit to actual
        getfield(PowerModelsProtection, Symbol("_map_eng2math_mc_admittance_$(type)!"))(data_math, data_eng; pass_props=get(eng2math_passthrough, type, String[]))
    end
end


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

function populate_bus_voltages!(data::Dict{String,Any})
    for (i, transformer) in data["transformer"]
        f_bus = transformer["f_bus"]
        t_bus = transformer["t_bus"]
        if haskey(transformer, "tm_nom")
            transformer["phases"] == 3 ? multi = 1 / sqrt(3) : multi = 1
            if !haskey(data["bus"][string(f_bus)], "vbase")
                data["bus"][string(f_bus)]["vbase"] = transformer["tm_nom"][1] * multi
            end
            # Vector{Vector{Int}}
            if typeof(t_bus) == Vector{Int64}
                for (indx, bus) in enumerate(t_bus)
                    if !haskey(data["bus"][string(bus)], "vbase")
                        data["bus"][string(bus)]["vbase"] = transformer["tm_nom"][indx+1] * multi
                    end
                end
            else
                if !haskey(data["bus"][string(t_bus)], "vbase")
                    data["bus"][string(t_bus)]["vbase"] = transformer["tm_nom"][2] * multi
                end
            end
        end
    end

    propagate_voltages!(data)

    for (i, gen) in data["gen"]
        if !haskey(data["bus"][string(gen["gen_bus"])], "vbase")
            # if gen["element"] == VoltageSourceElement
            if gen["model_type"] == "pv_systems"
                data["bus"][string(gen["gen_bus"])]["vbase"] = gen["vg"][1]
            end
        end
    end
    propagate_voltages!(data)

end


function propagate_voltages!(data::Dict{String,Any})
    buses = collect(keys(data["bus"]))
    for (i, bus) in data["bus"]
        !haskey(bus, "vbase") ? filter!(n -> n != string(i), buses) : nothing
    end

    found = true
    while found
        found = false
        for (i, branch) in data["branch"]
            f_bus = string(branch["f_bus"])
            t_bus = string(branch["t_bus"])
            if f_bus in buses
                if t_bus in buses
                    nothing
                else
                    data["bus"][t_bus]["vbase"] = data["bus"][f_bus]["vbase"]
                    found = true
                    push!(buses, t_bus)
                end
            elseif t_bus in buses
                if f_bus in buses
                    nothing
                else
                    data["bus"][f_bus]["vbase"] = data["bus"][t_bus]["vbase"]
                    found = true
                    push!(buses, f_bus)
                end
            end
        end
    end
end


function correct_grounds!(data::Dict{String,Any})
    for (i, transformer) in data["transformer"]
        for (i, config) in enumerate(transformer["configuration"])
            if config == _PMD.WYE
                buses = isa(transformer["dss"]["buses"], String) ? split(transformer["dss"]["buses"]) : transformer["dss"]["buses"]
                if occursin(".1.2.3.0", buses[i])
                    if i == 2
                        transformer["t_connections"] = [1, 2, 3, 4]
                        data["bus"][string(transformer["t_bus"])]["terminals"] = [1, 2, 3, 4]
                        data["bus"][string(transformer["t_bus"])]["grounded"] = Bool[0, 0, 0, 1]
                    end
                end
            end
        end
    end
end

