"Adds the fault to the model"
function ref_add_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end
    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:it][_PM.pm_it_sym][:nw][nw_id]
        nw_ref[:active_fault] = data["active_fault"]
    end
end


"Adds the fault to the model for multiconductor"
function ref_add_mc_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end
    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:it][_PMD.pmd_it_sym][:nw][nw_id]
        nw_ref[:active_fault] = data["active_fault"]
    end
end


"Calculates the power from solar based on inputs"
function ref_add_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    @debug "Adding solar refs"
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end
    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:it][_PMD.pmd_it_sym][:nw][nw_id]
        nw_ref[:solar_gfli] = Dict{Int,Any}()
        nw_ref[:solar_gfmi] = Dict{Int,Any}()
        for (i, gen) in nw_data["gen"]
            @debug "Adding solar refs for gen $i"


            if occursin("solar", gen["source_id"])
                if haskey(gen, "grid_forming")
                    @debug "Gen $i is grid-forming inverter:"
                    gen["grid_forming"] ? nw_ref[:solar_gfmi][parse(Int, i)] = gen["gen_bus"]  : nw_ref[:solar_gfli][parse(Int, i)] = gen["gen_bus"]
                else
                    nw_ref[:solar_gfli][parse(Int, i)] = gen["gen_bus"]
                end
                haskey(gen, "i_max") ? nothing : gen["i_max"] = (1/gen["dss"]["vminpu"]) * gen["dss"]["kva"] / (3 * 1000 * (data["settings"]["sbase"] * data["settings"]["power_scale_factor"] / 1e6))
                @debug "Gen $i imax = $(gen["i_max"])"
                haskey(gen, "solar_max") ? nothing : gen["solar_max"] = gen["dss"]["irradiance"] * gen["dss"]["pmpp"] / (data["settings"]["sbase"] * data["settings"]["power_scale_factor"] / 1e6) / 1000
                haskey(gen, "kva") ? nothing : gen["kva"] = gen["dss"]["kva"] / (data["settings"]["sbase"] * data["settings"]["power_scale_factor"] / 1e6) / 1000
                haskey(gen, "pf") ? nothing : gen["pf"] = gen["dss"]["pf"]
                # delete!(gen, "dss")
            end
        end
    end
end

"Calculates the power from solar based on inputs"
function ref_add_gen_dynamics!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    if _IM.ismultinetwork(data)
        nws_data = data["nw"]
    else
        nws_data = Dict("0" => data)
    end

    sbase2 = (data["settings"]["sbase"] * data["settings"]["power_scale_factor"] / 1e6)

    for (n, nw_data) in nws_data
        nw_id = parse(Int, n)
        nw_ref = ref[:it][_PMD.pmd_it_sym][:nw][nw_id]

        for (i, gen) in nw_data["gen"]
            if occursin("solar", gen["source_id"])
                continue
            end

            if !haskey(gen, "zr")
                gen["zr"] = [0, 0, 0,]
            end

            if !haskey(gen, "zx")
                if occursin("voltage_source", gen["source_id"])
                    gen["zx"] = [0, 0, 0]
                elseif haskey(gen, "dss") && haskey(gen["dss"], "xdp")
                    K = 1

                    if haskey(gen["dss"], "kw")
                        sbase1 = gen["dss"]["kw"]/1000
                        K = sbase2/sbase1
                    else
                        @warn "No kW specified for generator, not changing base for Xd'"
                    end

                    # Scaling factor for rebase
                    @debug "Old Xdp for gen$i = $(gen["dss"]["xdp"])"
                    @debug "Scaling Xdp by $K"
                    x = K*gen["dss"]["xdp"]
                    @debug "New Xdp for gen$i = $x"

                    gen["zx"] = repeat([x], 3)
                end
            end
        end
    end
end
