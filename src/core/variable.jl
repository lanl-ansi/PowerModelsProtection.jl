
# copy from PMs without power vars and constraints
function variable_branch_current(pm::_PMs.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMs.variable_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMs.variable_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PMs.variable_branch_series_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMs.variable_branch_series_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

# copy from PMs without power vars and constraints
function variable_gen(pm::_PMs.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMs.variable_gen_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMs.variable_gen_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

function variable_mc_branch_current(pm::_PMs.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PMD.variable_mc_branch_series_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_series_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

function variable_mc_transformer_current(pm::_PMs.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_transformer_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_transformer_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

function variable_mc_generation(pm::_PMs.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_generation_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_generation_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    # may want to keet this 
    _PMs.var(pm, nw)[:crg_bus] = Dict{Int, Any}()
    _PMs.var(pm, nw)[:cig_bus] = Dict{Int, Any}()
end