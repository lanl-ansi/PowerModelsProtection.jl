

const _a = exp(2im / 3 * pi)
const _A = [1 1 1; 1 _a^2 _a; 1 _a _a^2]

function transform_data_model_mc_ravens(
    data::Dict{String,<:Any};
    kron_reduce::Bool=true,
    phase_project::Bool=false,
    multinetwork::Bool=false,
    global_keys::Set{String}=Set{String}(),
    ravens2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
    ravens2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=false,
    make_pu_extensions::Vector{<:Function}=Function[],
    build_model::Bool=false,
    correct_network_data::Bool=true,
    kwargs...,
    )::Dict{String,Any}

    data_math = _map_ravens2math_mc_admittance(
        data;
        multinetwork=multinetwork,
        kron_reduce=kron_reduce,
        phase_project=phase_project,
        ravens2math_extensions=ravens2math_extensions,
        ravens2math_passthrough=ravens2math_passthrough,
        global_keys=global_keys,
    )

    correct_network_data && correct_network_data!(data_math; make_pu=make_pu, make_pu_extensions=make_pu_extensions)
    # data_math["m"] = data["m"]
    _apply_ravens_mc_admittance!(_map_ravens2math_mc_admittance_nw!, data_math, ravens2math_passthrough=ravens2math_passthrough, ravens2math_extensions=ravens2math_extensions)

    return data_math

end


function _apply_ravens_mc_admittance!(func!::Function, data1::Dict{String,<:Any}; kwargs...)
    func!(data1; kwargs...)
end


function _map_ravens2math_mc_admittance_nw!(data_math::Dict{String,<:Any}; ravens2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(), ravens2math_extensions::Vector{<:Function}=Function[])
    for type in _mc_admittance_asset_types # --> anything from missing from the model needed for the solve or admittance matrix maybe per unit to actual
        getfield(PowerModelsProtection, Symbol("_map_mc_admittance_$(type)!"))(data_math; pass_props=get(ravens2math_passthrough, type, String[]))
    end
end


"kinda copy of Juan's PMD revens schema"
function _map_ravens2math_mc_admittance(
    data_ravens::Dict{String,<:Any};
    ravens2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
    ravens2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=true,
    make_pu_extentions::Vector{<:Function}=Function[],
    global_keys::Set{String}=Set{String}(),
    build_model::Bool=false,
    kwargs...,
    )::Dict{String,Any}

    _data_ravens = deepcopy(data_ravens)

    _PMD.add_base_voltages!(_data_ravens; overwrite=false)

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

    if ismultinetwork(data_ravens)
        #  TODO multi network
    else
        data_math = Dict{String,Any}(
            "name" => get(_data_ravens, "name", ""),
            "per_unit" => get(_data_ravens, "per_unit", false),
            "data_model" => _PMD.MATHEMATICAL,
            "is_projected" => get(_data_ravens, "is_projected", false),
            "is_kron_reduced" => get(_data_ravens, "is_kron_reduced", false),
            "settings" => deepcopy(_settings),
            "time_elapsed" => get(_data_ravens, "time_elapsed", 1.0),
        )
    end
    data_math["controls"] = Dict{String, Any}()

    _PMD.apply_pmd!(_map_ravens2math_nw!, data_math, _data_ravens; ravens2math_passthrough=ravens2math_passthrough, ravens2math_extensions=ravens2math_extensions)
    
    return data_math
end


function _map_ravens2math_nw!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; ravens2math_passthrough::Dict{String,Vector{String}}=Dict{String,Vector{String}}(), ravens2math_extensions::Vector{<:Function}=Function[], nw::Int=nw_id_default)
    # need to add mn support
    data_math["map"] = Vector{Dict{String,Any}}([
        Dict{String,Any}("unmap_function" => "_map_math2eng_root!")
    ])

    _PMD._init_base_components!(data_math)

    for property in get(ravens2math_passthrough, "root", String[])
        if haskey(data_ravens, property)
            data_math[property] = deepcopy(data_ravens[property])
        end
    end

    for type in pmp_ravens_asset_types
        getfield(PowerModelsProtection, Symbol("_map_ravens2math_pmp_$(type)!"))(data_math, data_ravens; pass_props=get(ravens2math_passthrough, type, String[]))
    end

    # Custom ravens2math transformation functions
    for ravens2math_func! in ravens2math_extensions
        ravens2math_func!(data_math, data_ravens)
    end
    
    _PMD.find_conductor_ids!(data_math)
    _pmp_map_conductor_ids!(data_math)
    _PMD._map_settings_vbases_default!(data_math)
    populate_bus_voltages!(data_math)
    fix_voltages!(data_math)

end


"straight call to pmd"
function _map_ravens2math_pmp_connectivity_node!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_connectivity_node!(data_math, data_ravens; pass_props,)
end


"converts ravens n-winding transformers into mathematical ideal 2-winding lossless transformer branches and impedance branches to represent the loss model"
function _map_ravens2math_pmp_power_transformer!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)

    conducting_equipment = data_ravens["PowerSystemResource"]["Equipment"]["ConductingEquipment"]
    power_scale_factor = data_math["settings"]["power_scale_factor"]
    voltage_scale_factor = data_math["settings"]["voltage_scale_factor"]
    voltage_scale_factor_sqrt3 = voltage_scale_factor * sqrt(3)

    for (name, ravens_obj) in get(conducting_equipment, "PowerTransformer", Dict{Any,Dict{String,Any}}())

        # Build map first, so we can update it as we decompose the transformer
        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => String[],
            "unmap_function" => "_map_math2eng_transformer!",
        ))

        to_map = data_math["map"][end]["to"]
        
        if haskey(ravens_obj, "PowerTransformer.PowerTransformerEnd")
            
            # Get nrw: number of windings
            wdgs = ravens_obj["PowerTransformer.PowerTransformerEnd"]
            nrw = length(wdgs)

            # connections
            connections = Vector{Vector{Int64}}(undef, nrw)

            # configurations
            wdgs_confs = Vector{_PMD.ConnConfig}(undef, nrw)

            # RegulatorControls flag
            reg_controls = [false for _ in 1:nrw]
            reg_obj = [Dict() for _ in 1:nrw]

            # Transformer data for each winding
            vnom = Vector{Float64}(undef, nrw)
            snom = Vector{Float64}(undef, nrw)
            zbase = Vector{Float64}(undef, nrw)
            x_sc = Vector{Float64}(undef, nrw)
            r_s = Vector{Float64}(undef, nrw)
            g_sh = zeros(Float64, nrw)
            b_sh = zeros(Float64, nrw)

            # Init RatioTapChanger data (default)
            tm_set = Vector{Vector{Float64}}(undef, nrw)
            tm_lb = Vector{Vector{Float64}}(undef, nrw)
            tm_ub = Vector{Vector{Float64}}(undef, nrw)
            tm_fix = Vector{Vector{Bool}}(undef, nrw)
            tm_step = Vector{Vector{Float64}}(undef, nrw)

            for wdg_id in 1:nrw

                # wdg phasecode & terminals
                wdg_terminals = ravens_obj["ConductingEquipment.Terminals"][wdg_id]
                wdg_phasecode = wdg_terminals["Terminal.phases"]

                # wdg endNumber
                wdg_endNumber = wdgs[wdg_id]["TransformerEnd.endNumber"]

                # Connections (based on _phasecode_map)
                if haskey(_PMD._phasecode_map, wdg_phasecode)
                    connections[wdg_endNumber] = _PMD._phasecode_map[wdg_phasecode]
                else
                    @error("PhaseCode not supported yet!")
                end

                # nphases
                nphases = length(connections[wdg_endNumber])

                # Add terminals and voltage limits info. if missing
                node = _PMD._extract_name(wdg_terminals["Terminal.ConnectivityNode"])
                bus = data_math["bus_lookup"][node]
                bus_data = data_math["bus"][string(bus)]
                if !(haskey(bus_data, "terminals")) || (length(bus_data["terminals"]) < length(connections[wdg_endNumber]))
                    bus_data["terminals"] = connections[wdg_endNumber]
                    bus_data["vmin"] = fill(0.0, nphases)
                    bus_data["vmax"] = fill(Inf, nphases)
                    bus_data["grounded"] = zeros(Bool, nphases)
                end

                # wdgs configurations
                if wdgs[wdg_endNumber]["PowerTransformerEnd.connectionKind"] == "WindingConnection.Y" || wdgs[wdg_endNumber]["PowerTransformerEnd.connectionKind"] == "WindingConnection.Yn"
                    wdgs_confs[wdg_endNumber] = _PMD.WYE
                elseif wdgs[wdg_endNumber]["PowerTransformerEnd.connectionKind"] == "WindingConnection.D"
                    wdgs_confs[wdg_endNumber] = _PMD.DELTA
                else
                    @error("PowerTransformer ConnectionKind not supported yet!")
                end

                # Transformer data for each winding
                vnom[wdg_endNumber] = wdgs[wdg_endNumber]["PowerTransformerEnd.ratedU"]
                snom[wdg_endNumber] = wdgs[wdg_endNumber]["PowerTransformerEnd.ratedS"]
                zbase[wdg_endNumber] = (vnom[wdg_endNumber]^2)/snom[wdg_endNumber]

                # Transformer impedance when values are missing for other windings.
                xfmr_star_impedance = get(wdgs[wdg_endNumber], "TransformerEnd.StarImpedance", Dict())
                xfmr_star_impedance_r = get(xfmr_star_impedance, "TransformerStarImpedance.r", 0.0)

                if (xfmr_star_impedance == Dict())
                    xfmr_star_impedance_wdg1 = get(wdgs[1], "TransformerEnd.StarImpedance", Dict())
                    if (xfmr_star_impedance_wdg1 != Dict())
                        xfmr_star_impedance_r = get(xfmr_star_impedance_wdg1, "TransformerStarImpedance.r", 0.0).*(zbase[wdg_endNumber]/zbase[1])
                    end
                end

                xfmr_mesh_impedance = get(wdgs[wdg_endNumber], "TransformerEnd.MeshImpedance", Dict())
                xfmr_mesh_impedance_r = get(xfmr_mesh_impedance, "TransformerMeshImpedance.r", 0.0)

                if (xfmr_mesh_impedance == Dict())
                    xfmr_mesh_impedance_wdg1 = get(wdgs[1], "TransformerEnd.MeshImpedance", Dict())
                    if (xfmr_mesh_impedance_wdg1 != Dict())
                        xfmr_mesh_impedance_r = get(xfmr_mesh_impedance_wdg1, "TransformerMeshImpedance.r", 0.0).*(zbase[wdg_endNumber]/zbase[1])
                    end
                end

                # resistance
                r_s[wdg_endNumber] = get(wdgs[wdg_endNumber], "PowerTransformerEnd.r", (xfmr_star_impedance_r != 0.0 ? xfmr_star_impedance_r : xfmr_mesh_impedance_r)./2)    # divide by 2 because XFRMR Star Resistance includes both windings.

                # reactance
                x_sc[wdg_endNumber] = get(xfmr_mesh_impedance, "TransformerMeshImpedance.x",
                                        get(xfmr_star_impedance, "TransformerStarImpedance.x", 0.0))
                
                # admittance
                transf_core_impedance = get(wdgs[wdg_endNumber], "TransformerEnd.CoreAdmittance", Dict())
                g_sh[wdg_id] =  get(transf_core_impedance, "TransformerCoreAdmittance.g", 0.0)
                b_sh[wdg_id] = - get(transf_core_impedance, "TransformerCoreAdmittance.b", 0.0)


                # Set RatioTapChanger in specific wdg
                if haskey(wdgs[wdg_endNumber], "TransformerEnd.RatioTapChanger")

                    rtc_name = _extract_name(wdgs[wdg_endNumber]["TransformerEnd.RatioTapChanger"])
                    rtc_data = data_ravens["PowerSystemResource"]["TapChanger"]["RatioTapChanger"][rtc_name]

                    # tm_step
                    hstep = get(rtc_data, "TapChanger.highStep", 16)
                    lstep = get(rtc_data, "TapChanger.lowStep", -16)
                    step_dist = abs(hstep) + abs(lstep)
                    step_tap = 1/step_dist
                    tm_step[wdg_endNumber] = fill(step_tap, nphases)

                    # tm_set
                    step = get(rtc_data, "TapChanger.step", 1.0)    # Starting Tap changer position/step
                    tm_set[wdg_endNumber] = fill(step, nphases)

                    # tm_fix
                    ltcFlag = get(rtc_data, "TapChanger.ltcFlag", false)
                    if (ltcFlag == true)
                        tm_fix[wdg_endNumber] = zeros(Bool, nphases)
                    else
                        tm_fix[wdg_endNumber] = ones(Bool, nphases)
                    end

                    # tm_ub/tm_lb
                    neutralVoltPu = get(rtc_data, "TapChanger.neutralU", vnom[wdg_endNumber])/vnom[wdg_endNumber]
                    step_volt_increment = get(rtc_data, "RatioTapChanger.stepVoltageIncrement", 100.0)
                    volt_lb = neutralVoltPu + step_tap * (step_volt_increment/100.0) * lstep
                    volt_ub = neutralVoltPu + step_tap * (step_volt_increment/100.0) * hstep
                    tm_lb[wdg_endNumber] = fill(volt_lb, nphases)
                    tm_ub[wdg_endNumber] = fill(volt_ub, nphases)

                    # Regulator Control
                    if haskey(rtc_data, "TapChanger.TapChangerControl") && !all(tm_fix[wdg_endNumber])
                        reg_controls[wdg_endNumber] = true

                        if haskey(rtc_data, "TapChanger.TapChangerRatio")
                            ptRatio = get(rtc_data["TapChanger.TapChangerRatio"], "TapChanger.ptRatio", 60.0)
                            ctRating = get(rtc_data["TapChanger.TapChangerRatio"], "TapChanger.ctRating", 0.2)
                        else
                            ptRatio = 60.0
                            ctRating = 0.2
                        end

                        reg_obj[wdg_endNumber] = Dict{String,Any}(
                                "vreg" => fill(rtc_data["TapChanger.TapChangerControl"]["RegulatingControl.targetValue"], nphases),
                                "band" =>  fill(rtc_data["TapChanger.TapChangerControl"]["RegulatingControl.targetDeadband"], nphases),
                                "ptratio" => fill(ptRatio, nphases),
                                "ctprim" => fill(ctRating, nphases),
                                "r" => fill(rtc_data["TapChanger.TapChangerControl"]["TapChangerControl.lineDropR"], nphases),
                                "x" => fill(rtc_data["TapChanger.TapChangerControl"]["TapChangerControl.lineDropX"], nphases)
                        )
                    end

                else # default
                    tm_set[wdg_id] = fill(1.0, nphases)
                    tm_lb[wdg_id] = fill(0.9, nphases)
                    tm_ub[wdg_id] = fill(1.1, nphases)
                    tm_fix[wdg_id] = ones(Bool, nphases)
                    tm_step[wdg_id] = fill(1/32, nphases)
                end

            end
        
            # data is measured externally, but we now refer it to the internal side - some values are referred to wdg 1
            ratios = vnom/voltage_scale_factor

            x_sc = (x_sc./ratios[1]^2)
            r_s = r_s./ratios.^2
            g_sh = g_sh[1]*ratios[1]^2
            b_sh = b_sh[1]*ratios[1]^2

            rw = r_s .* ratios.^2 ./ zbase
            xsc = [(x_sc[1] * ratios[1]^2)/zbase[1]/100]

            # convert x_sc from list of upper triangle elements to an explicit dict
            y_sh = g_sh + im*b_sh
            z_sc = Dict([(key, im*x_sc[i]) for (i,key) in enumerate([(i,j) for i in 1:nrw for j in i+1:nrw])])

            # dimesions
            dims = length(tm_set[1])

            # init polarity
            polarity = fill(1, nrw)

            # Status
            status = haskey(ravens_obj, "Equipment.inService") ? ravens_obj["Equipment.inService"] : true
            status = status == true ? 1 : 0

            tm_nom = [wdgs_confs[wdg_id] == _PMD.DELTA ? vnom[wdg_id]/voltage_scale_factor : vnom[wdg_id]/voltage_scale_factor for wdg_id in 1:nrw]
    
            wdg_term = ravens_obj["ConductingEquipment.Terminals"][1]
            f_node_wdgterm = _PMD._extract_name(wdg_term["Terminal.ConnectivityNode"])
            wdg_term = ravens_obj["ConductingEquipment.Terminals"][2]
            t_node_wdgterm = _PMD._extract_name(wdg_term["Terminal.ConnectivityNode"])

            transformer_2wa_obj = Dict{String,Any}(
                "name"          => "transformer.$name",
                "source_id"     => "transformer.PowerTransformer.$name",
                "f_bus"         => data_math["bus_lookup"][f_node_wdgterm],
                "t_bus"         => data_math["bus_lookup"][t_node_wdgterm],
                "tm_nom"        => tm_nom,
                "f_connections" => connections[1],
                "t_connections" => connections[2],
                "configuration" => wdgs_confs,
                "polarity"      => polarity,
                "tm_set"        => tm_set,
                "tm_fix"        => tm_fix,
                "sm_ub"         => [get(wdgs[wdg_id], "PowerTransformerEnd.ratedS", Inf)/power_scale_factor for wdg_id in 1:nrw],
                "cm_ub"         => [get(wdgs[wdg_id], "PowerTransformerEnd.ratedI", Inf) for wdg_id in 1:nrw],
                "status"        => status,
                "index"         => length(data_math["transformer"])+1,
                "r_s"           => r_s,
                "rw"            => rw,
                "x_sc"          => x_sc,
                "xsc"           => xsc,
                "g_sh"          => g_sh,
                "b_sh"          => b_sh,
            )

            4 in transformer_2wa_obj["f_connections"] ? transformer_2wa_obj["phases"] = length(transformer_2wa_obj["f_connections"]) - 1 : transformer_2wa_obj["phases"] = length(transformer_2wa_obj["f_connections"])
            
            transformer_2wa_obj["vm_nom"] = [[zeros(1, length(transformer_2wa_obj["f_connections"]))] [zeros(1, length(transformer_2wa_obj["f_connections"]))]]
            if transformer_2wa_obj["phases"] == 1
                transformer_2wa_obj["vm_nom"][1][1] = transformer_2wa_obj["tm_nom"][1]
                transformer_2wa_obj["vm_nom"][2][1] = transformer_2wa_obj["tm_nom"][2]
            else
                for (i, _i) in enumerate(transformer_2wa_obj["f_connections"])
                    if _i != 4
                        transformer_2wa_obj["vm_nom"][1][i] = transformer_2wa_obj["tm_nom"][1]/sqrt(3)
                    end
                end
                for (i, _i) in enumerate(transformer_2wa_obj["t_connections"])
                    if _i != 4
                        transformer_2wa_obj["vm_nom"][2][i] = transformer_2wa_obj["tm_nom"][2]/sqrt(3)
                    end
                end
            end

            !(haskey(transformer_2wa_obj, "sm_nom")) ? transformer_2wa_obj["sm_nom"] = transformer_2wa_obj["sm_ub"] : nothing

            transformer_2wa_obj["leadLag"] = "lag"

            transformer_2wa_obj["tm_lb"] = tm_lb
            transformer_2wa_obj["tm_ub"] = tm_ub
            transformer_2wa_obj["tm_step"] = tm_step

            data_math["transformer"]["$(transformer_2wa_obj["index"])"] = transformer_2wa_obj

                # Add Regulator Controls 
            data_math["transformer"]["$(transformer_2wa_obj["index"])"]["controls"] = reg_obj

                # TODO: Center-Tapped Transformers (3 Windings)
                # if w==3 && eng_obj["polarity"][w]==-1 # identify center-tapped transformer and mark all secondary-side nodes as triplex by adding va_start
                # end

            push!(to_map, "transformer.$(transformer_2wa_obj["index"])")


        elseif haskey(ravens_obj, "PowerTransformer.TransformerTank")

            # Get tanks data
            tanks = ravens_obj["PowerTransformer.TransformerTank"]

            # number of tanks
            ntanks = length(tanks)

            # TODO: IMPORTANT ASSUMPTIONS
            # 1) assume there is at least 1 tank and that all tanks have the same number of windings (i.e., TransformerTankEnds)
            # 2) assume the number of phases is equal to the number of tanks - DEPRECATED
            # 3) assumes number of phases are indicated correctly in terminal # 1
            phasecode = ravens_obj["ConductingEquipment.Terminals"][1]["Terminal.phases"] # terminal 1 phasecode
            nphases = length(_PMD._phasecode_map[phasecode])
            # nphases = length(tanks) # assume nphases == ntanks

            nrw = length(tanks[1]["TransformerTank.TransformerTankEnd"])

            # init connections vector for combined transformer windings
            connections = [zeros(Int64, nphases) for _ in 1:nrw]

            # init nodes vector for combined transformer windings
            nodes = ["" for _ in 1:nrw]

            # init rs, x_sc, g_sh, and b_sh data per wdg/tank(phase)
            r_s = [zeros(Float64, nphases) for _ in 1:nrw]
            x_sc = [zeros(Float64, nphases) for _ in 1:nrw]
            g_sh = zeros(Float64, nphases)
            b_sh = zeros(Float64, nphases)

            # init sm_ub and cm_ub
            sm_ub = zeros(Float64, nrw)
            cm_ub = zeros(Float64, nrw)

            # init configuration - default WYE-WYE
            configuration = [_PMD.WYE for _ in 1:nrw]

            # RegulatorControls flag
            reg_controls = [false for _ in 1:nrw]
            reg_obj = [Dict() for _ in 1:nrw]

            # init vnom for all windings
            vnom = zeros(Float64, nrw)
            ratios = zeros(Float64, nrw)
            zbase = zeros(Float64, nrw)

            # temp store previous for checking
            nodes_prev = []
            configuration_prev = []
            vnom_prev = []

            # Init RatioTapChanger data (default)
            tm_set = Vector{Vector{Float64}}(fill(fill(1.0, nphases), nrw))
            tm_lb = Vector{Vector{Float64}}(fill(fill(0.9, nphases), nrw))
            tm_ub = Vector{Vector{Float64}}(fill(fill(1.1, nphases), nrw))
            tm_fix = Vector{Vector{Bool}}(fill(ones(Bool, nphases), nrw))
            tm_step = Vector{Vector{Float64}}(fill(fill(1/32, nphases), nrw))

            for tank_id in 1:ntanks

                # Get wdg data
                wdgs = tanks[tank_id]["TransformerTank.TransformerTankEnd"]

                # Tank Asset
                tank_asset_name = _PMD._extract_name(tanks[tank_id]["PowerSystemResource.AssetDatasheet"])
                tank_asset_data = data_ravens["AssetInfo"]["PowerTransformerInfo"][tank_asset_name]

                for wdg_id in 1:nrw

                    # wdg terminals & phasecode
                    wdg_terminals = ravens_obj["ConductingEquipment.Terminals"][wdg_id]
                    wdg_phasecode = wdg_terminals["Terminal.phases"]

                    # wdg endNumber
                    wdg_endNumber = wdgs[wdg_id]["TransformerEnd.endNumber"]

                    # from-and-to-nodes for wdgs
                    nodes[wdg_endNumber] = _PMD._extract_name(wdg_terminals["Terminal.ConnectivityNode"])

                    # Connections (based on _phasecode_map)
                    if haskey(_PMD._phasecode_map, wdg_phasecode)
                        phasecode_conns = _PMD._phasecode_map[wdg_phasecode]
                        if !(length(phasecode_conns)>1)
                            connections[wdg_endNumber][tank_id] = phasecode_conns[1]
                        else
                            connections[wdg_endNumber] = phasecode_conns
                        end
                    else
                        @error("PhaseCode not supported yet!")
                    end

                    # transformer tank end info.
                    transf_end_info = tank_asset_data["PowerTransformerInfo.TransformerTankInfos"][tank_asset_name]["TransformerTankInfo.TransformerEndInfos"]
                    vnom[wdg_endNumber] = transf_end_info[wdg_endNumber]["TransformerEndInfo.ratedU"] 
                    snom_wdg = transf_end_info[wdg_endNumber]["TransformerEndInfo.ratedS"]
                    zbase[wdg_endNumber] = (vnom[wdg_endNumber]^2) / snom_wdg
        

                    # Compute voltage ratios
                    ratios[wdg_endNumber] = vnom[wdg_endNumber]/voltage_scale_factor

                    # Transformer star impedance when values are missing for other windings.
                    xfmr_star_impedance = get(transf_end_info[wdg_endNumber], "TransformerEndInfo.TransformerStarImpedance", Dict())
                    xfmr_star_impedance_r = get(xfmr_star_impedance, "TransformerStarImpedance.r", 0.0)
                    if (xfmr_star_impedance == Dict())
                        xfmr_star_impedance_wdg1 = get(transf_end_info[1], "TransformerEndInfo.TransformerStarImpedance", Dict())
                        if (xfmr_star_impedance_wdg1 != Dict())
                            xfmr_star_impedance_r = get(xfmr_star_impedance_wdg1, "TransformerStarImpedance.r", 0.0).*(zbase[wdg_endNumber]/zbase[1])
                        end
                    end

                    # resistance computation
                    r_s[wdg_endNumber][tank_id] = get(transf_end_info[wdg_endNumber], "TransformerEndInfo.r", xfmr_star_impedance_r./2) # divide by 2 because XFRMR Star Resistance includes both windings.

                    # reactance computation
                    x_sc[wdg_endNumber][tank_id] = get(transf_end_info[wdg_endNumber], "TransformerEndInfo.x",
                                        get(xfmr_star_impedance, "TransformerStarImpedance.x", 0.0))

                    # -- alternative computation of xsc using sc tests
                    if haskey(transf_end_info[wdg_endNumber], "TransformerEndInfo.EnergisedEndShortCircuitTests")
                        leak_impedance_wdg = transf_end_info[wdg_endNumber]["TransformerEndInfo.EnergisedEndShortCircuitTests"][1]["ShortCircuitTest.leakageImpedance"]
                        rs_pct = (r_s[wdg_endNumber][tank_id]/zbase[wdg_endNumber])*100.0
                        x_sc[wdg_endNumber][tank_id] = (sqrt((leak_impedance_wdg/zbase[wdg_endNumber])^2 - (rs_pct+rs_pct)^2)/100)*zbase[wdg_endNumber]
                    end

                    # RS and XSC computation based on ratios
                    
                    r_s[wdg_endNumber][tank_id] = r_s[wdg_endNumber][tank_id]/ratios[wdg_endNumber]^2
                    x_sc[wdg_endNumber][tank_id] = (x_sc[wdg_endNumber][tank_id]/ratios[1]^2)   # w.r.t wdg1
                    
                    # b_sh and g_sh are always w.r.t wdg #1
                    if wdg_endNumber == 1
                        transf_end_noloadtest = get(transf_end_info[wdg_endNumber], "TransformerEndInfo.EnergisedEndNoLoadTests", [Dict()])
                        loss = get(transf_end_noloadtest[1], "NoLoadTest.loss", 0.0)
                        pctNoLoadLoss = (loss*100)/(snom_wdg/1000.0)    # loss is in kW, thus snom_wdg/1000.0
                        noLoadLoss = pctNoLoadLoss/100.0
                        g_sh_tank =  noLoadLoss/zbase[wdg_endNumber]
                        exct_current = get(transf_end_noloadtest[1], "NoLoadTest.excitingCurrent", pctNoLoadLoss)
                        cmag = sqrt(exct_current^2 - pctNoLoadLoss^2)/100   # cmag = pctImag/100 = sqrt(pctIexc^2 - pctNoLoadLoss^2)/100
                        b_sh_tank = -(cmag)/zbase[wdg_endNumber]
                        # data is measured externally, but we now refer it to the internal side
                        g_sh[tank_id] = g_sh_tank*ratios[1]^2   # w.r.t wdg1
                        b_sh[tank_id] = b_sh_tank*ratios[1]^2   # w.r.t wdg1
                    end

                    # configuration
                    conf = transf_end_info[wdg_endNumber]["TransformerEndInfo.connectionKind"]
                    if conf == "WindingConnection.Y" || conf == "WindingConnection.I" ||  conf == "WindingConnection.Yn"
                        configuration[wdg_endNumber] =  _PMD.WYE
                    elseif conf == "WindingConnection.D"
                        configuration[wdg_endNumber] = _PMD.DELTA
                    else
                        @error("TransformerTank ConnectionKind not supported yet!")
                    end

                    # add sm_ub if greater than existing (assumes the greatest value as the ratings for all phases in wdg)
                    semerg_wdg = get(transf_end_info[wdg_endNumber], "TransformerEndInfo.emergencyS", get(transf_end_info[wdg_endNumber], "TransformerEndInfo.ratedS", Inf))
                    if semerg_wdg > sm_ub[wdg_endNumber]
                        sm_ub[wdg_endNumber] = semerg_wdg
                    end

                    # add cm_ub if greater than existing for winding (assumes the greatest value as the ratings for all phases in wdg)
                    cm_wdg = get(transf_end_info[wdg_endNumber], "TransformerEndInfo.ratedI", Inf)
                    if cm_wdg > cm_ub[wdg_endNumber]
                        cm_ub[wdg_endNumber] = cm_wdg
                    end

                    # Set RatioTapChanger in specific wdg
                    if haskey(wdgs[wdg_endNumber], "TransformerEnd.RatioTapChanger")

                        rtc_name = _PMD._extract_name(wdgs[wdg_endNumber]["TransformerEnd.RatioTapChanger"])
                        rtc_data = data_ravens["PowerSystemResource"]["TapChanger"]["RatioTapChanger"][rtc_name]

                        # tm_step
                        hstep = get(rtc_data, "TapChanger.highStep", 16)
                        lstep = get(rtc_data, "TapChanger.lowStep", -16)
                        step_dist = abs(hstep) + abs(lstep)
                        step_tap = 1/step_dist
                        tm_step[wdg_endNumber] = fill(step_tap, nphases)

                        # tm_set
                        step = get(rtc_data, "TapChanger.step", 1.0)    # Starting Tap changer position/step
                        tm_set[wdg_endNumber] = fill(step, nphases)

                        # tm_fix
                        ltcFlag = get(rtc_data, "TapChanger.ltcFlag", false)
                        if (ltcFlag == true)
                            tm_fix[wdg_endNumber] = zeros(Bool, nphases)
                        else
                            tm_fix[wdg_endNumber] = ones(Bool, nphases)
                        end

                        # tm_ub/tm_lb
                        neutralVoltPu = get(rtc_data, "TapChanger.neutralU", vnom[wdg_endNumber])/vnom[wdg_endNumber]
                        step_volt_increment = get(rtc_data, "RatioTapChanger.stepVoltageIncrement", 100.0)
                        volt_lb = neutralVoltPu + step_tap * (step_volt_increment/100.0) * lstep
                        volt_ub = neutralVoltPu + step_tap * (step_volt_increment/100.0) * hstep
                        tm_lb[wdg_endNumber] = fill(volt_lb, nphases)
                        tm_ub[wdg_endNumber] = fill(volt_ub, nphases)

                        # Regulator Control
                        if haskey(rtc_data, "TapChanger.TapChangerControl") && !all(tm_fix[wdg_endNumber])
                            reg_controls[wdg_endNumber] = true

                            if haskey(rtc_data, "TapChanger.TapChangerRatio")
                                ptRatio = get(rtc_data["TapChanger.TapChangerRatio"], "TapChanger.ptRatio", 60.0)
                                ctRating = get(rtc_data["TapChanger.TapChangerRatio"], "TapChanger.ctRating", 0.2)
                            else
                                ptRatio = 60.0
                                ctRating = 0.2
                            end

                            reg_obj[wdg_endNumber] = Dict{String,Any}(
                                    "vreg" => fill(rtc_data["TapChanger.TapChangerControl"]["RegulatingControl.targetValue"], nphases),
                                    "band" =>  fill(rtc_data["TapChanger.TapChangerControl"]["RegulatingControl.targetDeadband"], nphases),
                                    "ptratio" => fill(ptRatio, nphases),
                                    "ctprim" => fill(ctRating, nphases),
                                    "r" => fill(rtc_data["TapChanger.TapChangerControl"]["TapChangerControl.lineDropR"], nphases),
                                    "x" => fill(rtc_data["TapChanger.TapChangerControl"]["TapChangerControl.lineDropX"], nphases)
                            )
                        end

                    end

                end
        
                ### --- Consistency checks across tanks ---
                # check that nodes are the same after first tank iter
                if tank_id != 1
                    @assert nodes == nodes_prev "nodes are not the same for all tanks! check ConnectivityNodes."  # check if node names are the same as expected
                else
                    nodes_prev = deepcopy(nodes)
                end

                # check that configurations across tanks are consistent
                if tank_id != 1
                    @assert configuration == configuration_prev "Configurations (e.g., WYE, DELTA) are not the same for all tanks and windings! check Configurations."  # check if node names are the same as expected
                else
                    configuration_prev = deepcopy(configuration)
                end

                # check that vnoms across tanks are consistent for wdgs
                if tank_id != 1
                    @assert vnom == vnom_prev "rated Voltages are not consistent for all tanks and windings! check TransformerEndInfo.ratedU values."  # check if node names are the same as expected
                else
                    vnom_prev = deepcopy(vnom)
                end

            end

            # Add information about bus/node if missing
            for i in 1:length(nodes)
                node = nodes[i]
                bus = data_math["bus_lookup"][node]
                bus_data = data_math["bus"][string(bus)]
                if !(haskey(bus_data, "terminals")) || (length(bus_data["terminals"]) < length(connections[i]))
                    bus_data["terminals"] = connections[i]
                    bus_data["vmin"] = fill(0.0, nphases)
                    bus_data["vmax"] = fill(Inf, nphases)
                    bus_data["grounded"] = zeros(Bool, nphases)
                end
            end

            # wdg i, tank 1  - assumes tank 1 always exists
            r_s = [r_s[i][1] for i in 1:nrw] 
            x_sc = [x_sc[i][1] for i in 1:nrw] # sum the x_sc for all tanks per wdg
            x_sc = [x_sc[1][1]]       # get x_sc wrt to wdg 1
            g_sh = g_sh[1]        # wrt to wdg 1
            b_sh = b_sh[1]        # wrt to wdg 1
         
            # convert x_sc from list of upper triangle elements to an explicit dict
            y_sh = g_sh + im*b_sh
            z_sc = Dict([(key, im*x_sc[i]) for (i,key) in enumerate([(i,j) for i in 1:nrw for j in i+1:nrw])])

            # init Polarity
            polarity = fill(1, nrw)

            # Status
            status = haskey(ravens_obj, "Equipment.inService") ? ravens_obj["Equipment.inService"] : true
            status = status == true ? 1 : 0

            # Compute total upper bounds based on number of tanks
            sm_ub = sm_ub.*ntanks
            cm_ub = cm_ub.*ntanks

            # Mathematical model for transformer
            tm_nom = zeros(nrw)
            for wdg_id in 1:nrw
                if ntanks >= 3
                    tm_nom[wdg_id] = configuration[wdg_id] == _PMD.DELTA ? vnom[wdg_id]/voltage_scale_factor : vnom[wdg_id]/voltage_scale_factor*sqrt(3)
                else
                    tm_nom[wdg_id] = configuration[wdg_id] == _PMD.DELTA ? vnom[wdg_id]/voltage_scale_factor : vnom[wdg_id]/voltage_scale_factor
                end
            end

            rw = r_s.*ratios.^2 ./ zbase
            xsc = x_sc*ratios[1]^2 /zbase[1]

            transformer_2wa_obj = Dict{String,Any}(
                "name"          => "transformer.$name",
                "source_id"     => "transformer.PowerTransformer.$name",
                "f_bus"         => data_math["bus_lookup"][nodes[1]],
                "t_bus"         => data_math["bus_lookup"][nodes[2]],
                "tm_nom"        => tm_nom,
                "f_connections" => connections[1],
                "t_connections" => connections[2],
                "configuration" => configuration,
                "polarity"      => polarity,
                "tm_set"        => tm_set,
                "tm_fix"        => tm_fix,
                "sm_ub"         => sm_ub./power_scale_factor,
                "cm_ub"         => cm_ub, # TODO: this may need scaling
                "status"        => status,
                "index"         => length(data_math["transformer"])+1,
                "r_s"           => r_s,
                "rw"            => rw,
                "x_sc"          => x_sc,
                "xsc"           => xsc,
                "g_sh"          => g_sh,
                "b_sh"          => b_sh,
            )
            
            4 in transformer_2wa_obj["f_connections"] ? transformer_2wa_obj["phases"] = length(transformer_2wa_obj["f_connections"]) - 1 : transformer_2wa_obj["phases"] = length(transformer_2wa_obj["f_connections"])

            transformer_2wa_obj["vm_nom"] = [[zeros(1, length(transformer_2wa_obj["f_connections"]))] [zeros(1, length(transformer_2wa_obj["f_connections"]))]]
            if transformer_2wa_obj["phases"] == 1
                transformer_2wa_obj["vm_nom"][1][1] = transformer_2wa_obj["tm_nom"][1]
                transformer_2wa_obj["vm_nom"][2][1] = transformer_2wa_obj["tm_nom"][2]
            else
                for (i, _i) in enumerate(transformer_2wa_obj["f_connections"])
                    if _i != 4
                        transformer_2wa_obj["vm_nom"][1][i] = transformer_2wa_obj["tm_nom"][1]/sqrt(3)
                    end
                end
                for (i, _i) in enumerate(transformer_2wa_obj["t_connections"])
                    if _i != 4
                        transformer_2wa_obj["vm_nom"][2][i] = transformer_2wa_obj["tm_nom"][2]/sqrt(3)
                    end
                end
            end

            !(haskey(transformer_2wa_obj, "sm_nom")) ? transformer_2wa_obj["sm_nom"] = transformer_2wa_obj["sm_ub"] : nothing
            # TODO fix phasing 
            transformer_2wa_obj["leadLag"] = "lag"

            # RatioTapChanger
            transformer_2wa_obj["tm_lb"] = tm_lb
            transformer_2wa_obj["tm_ub"] = tm_ub
            transformer_2wa_obj["tm_step"] = tm_step

            data_math["transformer"]["$(transformer_2wa_obj["index"])"] = transformer_2wa_obj

            # Add Regulator Controls
            data_math["transformer"]["$(transformer_2wa_obj["index"])"]["controls"] = reg_obj

            push!(to_map, "transformer.$(transformer_2wa_obj["index"])")
        end
    end
end


"straight call to pmd"
function _map_ravens2math_pmp_conductor!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_conductor!(data_math, data_ravens; pass_props,)
end


"straight call to pmd"
function _map_ravens2math_pmp_switch!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_switch!(data_math, data_ravens; pass_props,)
    for (i, switch) in data_math["switch"]
        if !(haskey(switch, "br_r"))
            n = length(switch["t_connections"])
            br_r = zeros(Float64, n, n)
            br_x = zeros(Float64, n, n)
            g_fr = zeros(Float64, n, n)
            b_fr = zeros(Float64, n, n)
            g_to = zeros(Float64, n, n)
            b_to = zeros(Float64, n, n)
            for j=1:n
                br_r[j,j] = 0.001
                br_x[j,j] = 0.001
            end
            switch["br_r"] = br_r
            switch["br_x"] = br_x
            switch["g_fr"] = g_fr
            switch["b_fr"] = b_fr
            switch["g_to"] = g_to
            switch["b_to"] = b_to
        end
    end
end


"""
Converts ravens voltage sources into mathematical generators and (if needed) impedance branches to represent the loss model.
"""
function _map_ravens2math_pmp_energy_source!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    energy_connections = data_ravens["PowerSystemResource"]["Equipment"]["ConductingEquipment"]["EnergyConnection"]
    voltage_scale_factor = data_math["settings"]["voltage_scale_factor"]
    voltage_scale_factor_sqrt3 = voltage_scale_factor * sqrt(3)

    for (name, ravens_obj) in get(energy_connections, "EnergySource", Dict{Any,Dict{String,Any}}())
        math_obj = _PMD._init_math_obj_ravens("EnergySource", name, ravens_obj, length(data_math["gen"]) + 1; pass_props=pass_props)
        math_obj["name"] = "energy_source.$name"

        # Get connectivity node info (bus info)
        connectivity_node = _PMD._extract_name(ravens_obj["ConductingEquipment.Terminals"][1]["Terminal.ConnectivityNode"])
        gen_bus = data_math["bus_lookup"][connectivity_node]
        math_obj["gen_bus"] = gen_bus
        bus_conn = data_math["bus"][string(gen_bus)]
        bus_conn["bus_type"] = 3  # Set bus type to PV bus

        # Handle phase-specific or three-phase connection
        connections = Vector{Int64}()

        if haskey(ravens_obj, "EnergySource.EnergySourcePhase")
            for phase_info in ravens_obj["EnergySource.EnergySourcePhase"]
                phase = _PMD._phase_map[phase_info["EnergySourcePhase.phase"]]
                push!(connections, phase)
            end
            math_obj["connections"] = connections
        else
            # Terminal Phases
            if haskey(ravens_obj["ConductingEquipment.Terminals"][1], "Terminal.phases")
                phasecode = ravens_obj["ConductingEquipment.Terminals"][1]["Terminal.phases"]
                math_obj["connections"] = _PMD._phasecode_map[phasecode]
            else
                math_obj["connections"] = bus_conn["terminals"]
            end
        end

        # Check that connections and bus terminals have the same number of phases, if not, assume connections is correct
        if (bus_conn["terminals"] != math_obj["connections"])
            bus_conn["terminals"] = math_obj["connections"]
            nphases = length(bus_conn["terminals"])
            # Add vmin and vmax to bus if missing (correct number of terminals)
            bus_conn["vmin"] = fill(0.0, nphases)
            bus_conn["vmax"] = fill(Inf, nphases)
            bus_conn["grounded"] = zeros(Bool, nphases)
        end

        nconductors = length(get(ravens_obj, "EnergySource.EnergySourcePhase", bus_conn["terminals"]))

        # Generator status and configuration
        math_obj["gen_status"] = haskey(ravens_obj, "Equipment.inService") ? ravens_obj["Equipment.inService"] : true
        math_obj["gen_status"] = math_obj["gen_status"] == true ? 1 : 0

        math_obj["configuration"] = get(ravens_obj, "EnergySource.connectionKind", _PMD.WYE)

        # Set the nominal voltage
        if haskey(ravens_obj, "ConductingEquipment.BaseVoltage")
            base_voltage_ref = _PMD._extract_name(ravens_obj["ConductingEquipment.BaseVoltage"])
            vnom = data_ravens["BaseVoltage"][base_voltage_ref]["BaseVoltage.nominalVoltage"] / sqrt(nconductors)
            data_math["settings"]["vbases_default"][connectivity_node] = vnom / voltage_scale_factor
        else
            vnom = ravens_obj["EnergySource.nominalVoltage"] / sqrt(nconductors)
            data_math["settings"]["vbases_default"][connectivity_node] = vnom / voltage_scale_factor
        end

        # Power, voltage, and limits
        nphases = nconductors  # You can adjust nphases based on your specific kron reduction logic if needed
        fill_values = (v) -> fill(v, nphases)
        math_obj["pg"] = get(ravens_obj, "EnergySource.activePower", fill_values(0.0))
        math_obj["qg"] = get(ravens_obj, "EnergySource.reactivePower", fill_values(0.0))
        math_obj["vg"] = fill(get(ravens_obj, "EnergySource.voltageMagnitude", voltage_scale_factor_sqrt3) / voltage_scale_factor_sqrt3, nphases)
        math_obj["pmin"] = get(ravens_obj, "EnergySource.pMin", fill_values(-Inf))
        math_obj["pmax"] = get(ravens_obj, "EnergySource.pMax", fill_values(Inf))
        math_obj["qmin"] = get(ravens_obj, "EnergySource.qMin", fill_values(-Inf))
        math_obj["qmax"] = get(ravens_obj, "EnergySource.qMax", fill_values(Inf))

        # Control mode and source ID
        math_obj["control_mode"] = Int(get(ravens_obj, "EnergySource.connectionKind", _PMD.ISOCHRONOUS))
        math_obj["source_id"] = "EnergySource.$name"
        math_obj["admit_model"] = VoltageSourceElement
        
        # Add generator cost model
        _PMD._add_gen_cost_model!(math_obj, ravens_obj)

        # a = 1*exp(120im*pi/180)
        # A = [1 1 1;1 a a^2;1 a^2 a]
        r1 = get(ravens_obj, "EnergySource.r", zeros(1, 1))
        x1 = get(ravens_obj, "EnergySource.x", zeros(1, 1))
        r0 = get(ravens_obj, "EnergySource.r0", zeros(1, 1))
        x0 = get(ravens_obj, "EnergySource.x0", zeros(1, 1))
        rs = zeros(nconductors, nconductors)
        xs = zeros(nconductors, nconductors)

        if r0 == 0 && x0 == 0
            for n in 1:nconductors
                rs[n,n] = r1
                xs[n,n] = x1
            end
        else
            z_012 = zeros(Complex{Float64}, nconductors, nconductors)
            z_012[1,1] = r0 + x0 * 1im
            z_012[2,2] = z_012[3,3] = r1 + x1 * 1im
            z_abc = _A * z_012 * inv(_A)
            rs = real.(z_abc)
            xs = imag.(z_abc)
        end

        math_obj["rs"] = rs
        math_obj["xs"] = xs

        # Check for impedance and adjust bus type if necessary
        map_to = "gen.$(math_obj["index"])"

        vm_lb = math_obj["control_mode"] == Int(_PMD.ISOCHRONOUS) ? fill(ravens_obj["EnergySource.voltageMagnitude"] / voltage_scale_factor_sqrt3, nphases) : get(ravens_obj, "EnergySource.vMin", fill(1.0, nphases))
        vm_ub = math_obj["control_mode"] == Int(_PMD.ISOCHRONOUS) ? fill(ravens_obj["EnergySource.voltageMagnitude"] / voltage_scale_factor_sqrt3, nphases) : get(ravens_obj, "EnergySource.vMax", fill(1.0, nphases))

        data_math["bus"]["$gen_bus"]["vmin"] = [vm_lb..., fill(0.0, nconductors - nphases)...]
        data_math["bus"]["$gen_bus"]["vmax"] = [vm_ub..., fill(Inf, nconductors - nphases)...]
        data_math["bus"]["$gen_bus"]["vm"] = fill(ravens_obj["EnergySource.voltageMagnitude"] / voltage_scale_factor_sqrt3, nphases)
        data_math["bus"]["$gen_bus"]["va"] = rad2deg.(_PMD._wrap_to_pi.([-2 * π / nphases * (i - 1) + get(ravens_obj, "EnergySource.voltageAngle", 0.0) for i in 1:nphases]))
        data_math["bus"]["$gen_bus"]["bus_type"] = _PMD._compute_bus_type(bus_conn["bus_type"], math_obj["gen_status"], math_obj["control_mode"])

        4 in math_obj["connections"] ? math_obj["phases"] = length(math_obj["connections"]) - 1 : math_obj["phases"] = length(math_obj["connections"])

        data_math["gen"]["$(math_obj["index"])"] = math_obj
        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => map_to,
            "unmap_function" => "_map_math2eng_voltage_source!",
        ))

    end
end


"straight call to pmd"
function _map_ravens2math_pmp_energy_consumer!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_energy_consumer!(data_math, data_ravens; pass_props,)
    for (i, load) in data_math["load"]
        load["phases"] = length(load["pd"])
        if !(haskey(load, "vlowpu"))
            load["vlowpu"] =  .50
        end
        if !(haskey(load, "vmaxpu"))
            load["vmaxpu"] =  1.05
        end
        load["i_last"] = zeros(Complex{Float64}, 1, length(load["connections"]))
        if load["model"] == _PMD.POWER
            load["response"] = ConstantPQ
        end
    end
end


"straight call to pmd"
function _map_ravens2math_pmp_shunt_compensator!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_shunt_compensator!(data_math, data_ravens; pass_props,)
end


"straight call to pmd"
function _map_ravens2math_pmp_rotating_machine!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_rotating_machine!(data_math, data_ravens; pass_props,)
    for (name, gen) in data_math["gen"]
        gen["phases"] = length(gen["pg"])
        if haskey(gen, "vbase")
            kv = gen["vbase"]/sqrt(3)
            gen["vnom_kv"] = fill(kv, length(gen["pg"]))
        end
        if occursin("RotatingMachine", gen["source_id"])
            zbase = (gen["vnom_kv"][1] * data_math["settings"]["voltage_scale_factor"])^2/(abs(gen["pmax"][1] + 1im*gen["qmax"][1]) *data_math["settings"]["power_scale_factor"])
            gen["admit_model"] = RotatingMachineElement
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


"straight call to pmd"
function _map_ravens2math_pmp_power_electronics!(data_math::Dict{String,<:Any}, data_ravens::Dict{String,<:Any}; pass_props::Vector{String}=String[], nw::Int=nw_id_default)
    _PMD._map_ravens2math_power_electronics!(data_math, data_ravens; pass_props,)
    for (name, gen) in data_math["gen"]
        if occursin("PhotoVoltaicUnit", gen["source_id"])
            if length(gen["vg"]) == 1
                gen["vg"] = gen["vg"] .* 1/sqrt(3)
            end
            gen["grid_forming"] = false
            sum(gen["pg"]) == 0.0 ? gen["pg"] = gen["pmax"] : nothing 
            gen["admit_model"] = PVSystemElement
            4 in gen["connections"] ? gen["phases"] = length(gen["connections"]) - 1 : gen["phases"] = length(gen["connections"])
            gen["balanced"] = "true"
            gen["vminpu"] = 1/1.5
            irated = abs(gen["pmax"][1] + 1im * gen["qmax"][1]) * data_math["settings"]["power_scale_factor"] / (gen["vg"][1] * data_math["settings"]["voltage_scale_factor"])
            gen["imax"] = irated * 1/gen["vminpu"]
            gen["i_last"] = zeros(Complex{Float64}, gen["phases"], 1)    
        end
    end
    for (name, storage) in data_math["storage"]
        storage["grid_forming"] = true
        storage["admit_model"] = StorageElement
        4 in storage["connections"] ? gen["phases"] = length(storage["connections"]) - 1 : storage["phases"] = length(storage["connections"])
        bus = storage["storage_bus"]
        storage_bus = deepcopy(data_math["bus"]["$(bus)"])
        bus_indx = length(data_math["bus"])+1
        switch_indx = length(data_math["switch"])+1
        storage_bus["index"] = bus_indx
        storage_bus["bus_i"] = bus_indx
        storage_bus["name"] = storage["name"] * "_virtual"
        storage["switch"] = switch_indx
        data_math["bus"]["$(bus_indx)"] = storage_bus
        switch = Dict{String, Any}(
            "f_connections" => storage["connections"], 
            "state" => 1, 
            "rate_b" => fill(Inf, length(storage["connections"])), 
            "name" => "$(storage["name"])_switch", 
            "status" => 1, 
            "rate_c" => fill(Inf, length(storage["connections"])), 
            "c_rating_b" => fill(Inf, length(storage["connections"])),
            "source_id" => "Switch.$(storage["name"])",
            "t_connections" => storage["connections"], 
            "f_bus" => bus_indx,
            "sm_ub" => fill(1.5e7, length(storage["connections"])),
            "current_rating" => fill(1e6, length(storage["connections"])), 
            "dispatchable" => 1, 
            "t_bus" => bus, 
            "index" => switch_indx, 
            "c_rating_c" => fill(Inf, length(storage["connections"])),
        )
        data_math["switch"]["$(switch_indx)"] = switch
        storage["storage_bus"] = bus_indx
    end
end
