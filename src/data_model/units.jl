""
function _rebase_pu_fault!(nw::Dict{String,<:Any}, data_math::Dict{String,<:Any}, bus_vbase, line_vbase, sbase::Real, sbase_old::Real, voltage_scale_factor)
    if haskey(nw, "fault")
        for (_,fault) in nw["fault"]
            vbase = bus_vbase["$(fault["fault_bus"])"]
            z_scale = 1 / (vbase^2 / sbase * voltage_scale_factor)
            y_scale = 1 / z_scale

            _PMD._scale_props!(fault, ["g", "b"], y_scale)
        end
    end
end


""
function _rebase_pu_gen_dynamics!(nw::Dict{String,<:Any}, data_math::Dict{String,<:Any}, bus_vbase, line_vbase, sbase::Real, sbase_old::Real, voltage_scale_factor)
    if haskey(nw, "gen")
        for (_,gen) in nw["gen"]
            vbase = bus_vbase["$(gen["gen_bus"])"]
            vbase_old = get(gen, "vbase", 1.0/nw["settings"]["voltage_scale_factor"])
            vbase_scale = vbase_old/vbase
            sbase_scale = sbase_old/sbase

            _PMD._scale_props!(gen, ["zr", "zx"], sbase_scale)
            _PMD._scale_props!(gen, ["i_max", "solar_max", "kva"], sbase_scale)
        end
    end
end


""
const _pmp_dimensionalize_math_extensions = Dict{String,Dict{String,Vector{String}}}(
    "branch" => Dict{String,Vector{String}}(
        "ibase" => String["csr_fr", "csi_fr", "fault_current"]
    ),
    "bus" => Dict{String,Vector{String}}(
        "ibase" => String["cfr_bus", "cfi_bus"]
    ),
)


""
function make_fault_si!(nw_sol::Dict{String,<:Any}, nw_data::Dict{String,<:Any}, solution::Dict{String,<:Any}, math_model::Dict{String,<:Any})
    if haskey(nw_sol, "fault")
        for (id,fault) in nw_sol["fault"]

            vbase = nw_data["bus"]["$(nw_data["fault"][id]["fault_bus"])"]["vbase"]
            sbase = nw_sol["settings"]["sbase"]
            ibase = sbase / vbase

            for prop in ["cfr", "cfi", "fault_current"]
                if haskey(fault, prop)
                    fault[prop] = _PMD._apply_func_vals(fault[prop], x->x*ibase)
                end
            end
        end
    end
end
