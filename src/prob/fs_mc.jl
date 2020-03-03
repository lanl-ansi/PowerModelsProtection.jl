
function run_mc_fault_study(data::Dict{String,Any}, solver; kwargs...)
    check_pf!(data, solver)
    solution = Dict{String, Any}()
    for (i,fault) in data["fault"]
        data["active_fault"] = fault
        result = _PMs.run_model(data, _PMs.IVRPowerModel, solver, build_mc_fault_study; ref_extensions=[ref_add_fault!], kwargs...)
        println(result)
    end
    return solution
end

""
function run_fault_study(file::String, solver; kwargs...)
    return run_mc_fault_study(parse_file(file), solver; kwargs...)
end
""

function build_mc_fault_study(pm::_PMs.AbstractPowerModel)

    _PMD.variable_mc_voltage(pm, bounded = false)
    variable_mc_branch_current(pm, bounded = false)
    variable_mc_transformer_current(pm, bounded = false)
    _PMD.variable_mc_generation(pm, bounded = false) 
 
#     # gens should be constrained before KCL, or Pd/Qd undefined
#     for id in PMs.ids(pm, :gen)
#         PMD.constraint_mc_generation(pm, id)
#     end


#     for (i,bus) in PMs.ref(pm, :bus)
#         # do need a new version to handle gmat
#         constraint_mc_fault_current_balance(pm, i)        
#     end

#     for (i,gen) in ref(pm, :gen)
#         # do I need a new version for multiconductor
#         constraint_mc_gen_fault_voltage_drop(pm, i)
#     end

#     for i in PMs.ids(pm, :branch)
#         PMD.constraint_mc_current_from(pm, i)
#         PMD.constraint_mc_current_to(pm, i)

#         PMD.constraint_mc_voltage_drop(pm, i)
#     end

#     for i in PMs.ids(pm, :transformer)
#         PMD.constraint_mc_trans(pm, i)
#     end
# end
end