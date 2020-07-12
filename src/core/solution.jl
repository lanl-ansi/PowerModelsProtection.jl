
""
function solution_fs!(pm::_PM.AbstractPowerModel, sol::Dict{String,Any})
    # sol["fault"] = ref(pm, pm.cnw, :active_fault)
    # sol["fault"]["currents"] = Dict{String, Any}()
    # add_branch_currents!(pm, sol)
    # add_tansformer_currents!(pm, sol)
end


""
function add_tansformer_currents!(pm::_PM.AbstractPowerModel, sol::Dict{String,Any})
    s_base = sol["baseMVA"] * 1000
    for (l,i,j) in ref(pm, pm.cnw, :arcs_from_trans)
        v_base = ref(pm, pm.cnw, :bus, i)["vbase"]
        i_base = sqrt(3) * s_base/ v_base
        trans = ref(pm, pm.cnw, :bus, j)["name"]
        name = string(ref(pm, pm.cnw, :bus, i)["name"], ">>", trans)
        sol["fault"]["currents"][name] = [abs(JuMP.value(var(pm, pm.cnw, :crt, (l,i,j))[c]) + JuMP.value(var(pm, pm.cnw, :cit, (l,i,j))[c]) * im ) * i_base for c in 1:3]
    end
end


""
function add_branch_currents!(pm::_PM.AbstractPowerModel, sol::Dict{String,Any})
    s_base = sol["baseMVA"] * 1000
    for (index, branch) in ref(pm, pm.cnw, :branch)
        if occursin("line.", branch["source_id"])
            v_base = ref(pm, pm.cnw, :bus, branch["t_bus"])["vbase"]
            i_base = sqrt(3) * s_base/ v_base
            bus_i = string(index)
            name = branch["source_id"]
            sol["fault"]["currents"][name] = [abs(sol["branch"][bus_i]["csr_fr"][c] + sol["branch"][bus_i]["csi_fr"][c] *im) * i_base for c in 1:3]
        end
    end
end

function add_solution!(sol::Dict{String,Any}, data::Dict{String,Any})
    sol["fault"] = Dict{String,Any}()
    sol["fault"]["currents"] = Dict{String,Any}()
    for (name,line) in sol["line"]
        for (i, branch) in data["branch"]
            if branch["name"] == name
                csr_fr = [data["baseMVA"] * 1000/branch["vbase"] * line["csr_fr"][c] for c in 1:3]
                csi_fr = [data["baseMVA"] * 1000/branch["vbase"] * line["csi_fr"][c] for c in 1:3]
                sol["fault"]["currents"][name] = [abs(csr_fr[c] + csi_fr[c] *im) for c in 1:3]
            end
        end
    end
end

function make_line(data::Any, n::Int)
    str = ""
    for i = 1 : length(data)
        if typeof(data[i]) != String
            if typeof(data[i]) == Float64
                data[i] = round(data[i],digits=3)
            end
            data[i] = string(data[i])
        end
        while length(data[i]) < n
            data[i] = string(data[i], " ")
        end
        str = string(str, data[i])
    end
    str = string(str, "\n")
    return str      
end

function output_solution(file::String, solution::Dict{String, Any}, data::Dict{String, Any}; format = "lines")
    if format == "buses"
        output_solution_buses(file, solution, data)
    end
end

function output_solution_buses(file::String, solution::Dict{String, Any}, data::Dict{String, Any})
    n = 15
    order = Array{String,1}()
    for key in keys(solution)
        push!(order, key)
    end
    bus = Dict{String, Any}()
    for (i, branch) in data["line"]
        !haskey(bus, branch["t_bus"]) ? bus[branch["t_bus"]] = [] : nothing 
        !haskey(bus, branch["f_bus"]) ? bus[branch["f_bus"]] = [] : nothing 
        push!(bus[branch["t_bus"]], branch["dss"]["name"])
        push!(bus[branch["f_bus"]], branch["dss"]["name"])
    end
    for (i, trans) in data["transformer"]
        !haskey(bus, trans["bus"][1]) ? bus[trans["bus"][1]] = [] : nothing 
        !haskey(bus, trans["bus"][2]) ? bus[trans["bus"][2]] = [] : nothing 
        push!(bus[trans["bus"][1]], trans["dss"]["name"])
        push!(bus[trans["bus"][2]], trans["dss"]["name"])
    end
    open(file, "w+") do io
        write(io, "FAULT STUDY OUTPUT\n\n")
        write(io, "Three Phase Fault\n")
        line = make_line(["Bus", "Node 1", "Node 2", "Node 3", "Feasible"], n)
        write(io, line)
        for i = 1:length(order)
            if haskey(solution, order[i])
                if haskey(solution[order[i]], "3p")
                    for (j, fault) in solution[order[i]]["3p"]
                        vals = [0.0 0.0 0.0]
                        for cnd = 1:3
                            for line in bus[order[i]]
                                if line in keys(fault["solution"]["fault"]["currents"])
                                    vals[cnd] += fault["solution"]["fault"]["currents"][line][cnd]
                                end
                            end
                        end
                        solution[order[i]]["3p"][j]["termination_status"] == MOI.LOCALLY_SOLVED ? f = 1 : f = 0
                        line = make_line([order[i], vals[1], vals[2], vals[3], f], n)
                        write(io, line)
                    end
                end
            end
        end
        write(io, "\n\nLine Line Faults\n")
        line = make_line(["Bus", "Node 1", "Node 2", "Node 3", "Feasible"], n)
        write(io, line)
        for i = 1:length(order)
            if haskey(solution, order[i])
                if haskey(solution[order[i]], "ll")
                    for (j, fault) in solution[order[i]]["ll"]
                        vals = [0.0 0.0 0.0]
                        for cnd = 1:3
                            for line in bus[order[i]]
                                if line in keys(fault["solution"]["fault"]["currents"])
                                    vals[cnd] += fault["solution"]["fault"]["currents"][line][cnd]
                                end
                            end
                        end
                        solution[order[i]]["ll"][j]["termination_status"] == MOI.LOCALLY_SOLVED ? f = 1 : f = 0
                        line = make_line([order[i], vals[1], vals[2], vals[3], f], n)
                        write(io, line)
                    end
                end
            end
        end
        write(io, "\n\nLine Ground Faults\n")
        line = make_line(["Bus", "Node 1", "Node 2", "Node 3", "Feasible"], n)
        write(io, line)
        for i = 1:length(order)
            if haskey(solution, order[i])
                if haskey(solution[order[i]], "lg")
                    for (j, fault) in solution[order[i]]["lg"]
                        vals = [0.0 0.0 0.0]
                        for cnd = 1:3
                            for line in bus[order[i]]
                                if line in keys(fault["solution"]["fault"]["currents"])
                                    vals[cnd] += fault["solution"]["fault"]["currents"][line][cnd]
                                end
                            end
                        end
                        solution[order[i]]["lg"][j]["termination_status"] == MOI.LOCALLY_SOLVED ? f = 1 : f = 0
                        line = make_line([order[i], vals[1], vals[2], vals[3], f], n)
                        write(io, line)
                    end
                end
            end
        end


    # Dict{String,Any}("primary" => Any["quad", "pv_line", "ohline"],"sourcebus" => Any["ohline"],"loadbus" => Any["quad"],"pv_bus" => Any["pv_line"])
    # result["loadbus"]["3p"][1]["solution"]["fault"]["currents"]["pv_line"][1]
        
    
    #     write(io, "FAULT STUDY OUTPUT\n\n")
        
        
        
        # for (i, bus)
    end
end