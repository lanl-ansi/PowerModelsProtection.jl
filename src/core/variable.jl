"copies from PowerModels and PowerModelsDistribution without power vars"
function variable_branch_current(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PM.variable_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PM.variable_branch_series_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_branch_series_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_gen(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PM.variable_gen_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_gen_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_gen_loading(pm, nw=nw, report=report; kwargs...)
end


"variable: `pg[j]` for `j` in `gen`"
function variable_gen_loading(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    kg = var(pm, nw)[:kg] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :gen)], base_name="$(nw)_kg",
        start = _PM.comp_start_value(ref(pm, nw, :gen, i), "kg_start")
    )

    for (i, gen) in ref(pm, nw, :gen)
        JuMP.set_lower_bound(kg[i], 0)
        JuMP.set_upper_bound(kg[i], 1)
    end

    report && _PM.sol_component_value(pm, nw, :gen, :kg, ids(pm, nw, :gen), kg)
end

""
function variable_mc_branch_current(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PMD.variable_mc_branch_series_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_series_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_mc_transformer_current(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_transformer_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_transformer_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_mc_generation(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_generation_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_generation_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    var(pm, nw)[:crg_bus] = Dict{Int, Any}()
    var(pm, nw)[:cig_bus] = Dict{Int, Any}()
end
