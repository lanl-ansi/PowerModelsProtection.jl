
function correct_network_data!(data::Dict{String,Any}; make_pu::Bool=true, make_pu_extensions::Vector{<:Function}=Function[])
    if _PMD.iseng(data)
        check_eng_data_model(data)
    elseif _PMD.ismath(data)
        g = check_graph_connectivity(data)
        _PMD.check_branch_loops(data)

        _PMD.correct_branch_directions!(data)
        _PMD.check_branch_loops(data)
        # println(keys(data["gen"]))
        # for (i, gen) in data["gen"]
        #     println(gen)
        # end
        # for (i, bus) in data["bus"]
        #     println(bus)
        # end
        # println(keys(data["bus"]))
        # println(data["switch"])
        # # println(data["gen"])
        # oooo
        # _PMD.correct_bus_types!(data)

        # add function to remove unconnected components
        _PMD.propagate_network_topology!(data)

        # if make_pu
        #     make_per_unit!(data; make_pu_extensions=make_pu_extensions)

        #     correct_mc_voltage_angle_differences!(data)
        #     correct_mc_thermal_limits!(data)

        #     correct_cost_functions!(data)
        #     standardize_cost_terms!(data)
        # end
        data["graph"] = g
    end
end
