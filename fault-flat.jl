using PowerModels, JuMP, Ipopt

include("powermodelsio.jl")

const PMs = PowerModels

function run_fault_study(file, solver; kwargs...)
    return run_model(file, PowerModels.IVRPowerModel, solver, build_fault_study; kwargs...)
end

function build_fault_study(pm::PMs.AbstractPowerModel)
    # voltage magnitude & angles at generator buses# should be fixed to the OPF results
    variable_voltage(pm, bounded = false)
    variable_branch_current(pm, bounded = false)
    variable_gen(pm, bounded = false) 
  
    for (i,bus) in ref(pm, :bus)
        constraint_fault_current_balance(pm, i)
    end

    for (i,gen) in ref(pm, :gen)
        constraint_gen_fault_voltage_drop(pm, i)
    end
    
    for i in ids(pm, :branch)
        constraint_current_from(pm, i)
        constraint_current_to(pm, i)
        constraint_voltage_drop(pm, i)
    end
end


# from constraint_template.jl
function constraint_fault_current_balance(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    # this breaks stuff
    # if !haskey(con(pm, nw, cnd), :kcl_cr)
    #     con(pm, nw, cnd)[:kcl_cr] = Dict{Int,JuMP.ConstraintRef}()
    # end
    # if !haskey(con(pm, nw, cnd), :kcl_ci)
    #     con(pm, nw, cnd)[:kcl_ci] = Dict{Int,JuMP.ConstraintRef}()
    # end

    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    # bus_faults = ref(pm, nw, :bus_faults, i)
    bus_faults = []

    # TODO: replace with list comprehension
    for (k,f) in ref(pm, :fault)
        if f["bus"] == i
            push!(bus_faults, k)
        end
    end
            
    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)
    
    bus_gf =  Dict(k => ref(pm, nw, :fault, k, "gf") for k in bus_faults)
    # println("bus_gf = $bus_gf")

    constraint_fault_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs, bus_gf)
end

# from form/ivr.jl
function constraint_fault_current_balance(pm::AbstractIVRModel, n::Int, i, bus_arcs, bus_gens, bus_gs, bus_bs, bus_gf)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    cr =  var(pm, n, :cr)
    ci =  var(pm, n, :ci)

    crg =  var(pm, n, :crg)
    cig =  var(pm, n, :cig)    

    JuMP.@NLconstraint(pm.model, sum(cr[a] for a in bus_arcs)
                                ==
                                sum(crg[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs))*vr + sum(bs for bs in values(bus_bs))*vi
                                - sum(gf for gf in values(bus_gf))*vr 
                                )
    JuMP.@NLconstraint(pm.model, sum(ci[a] for a in bus_arcs)
                                ==
                                sum(cig[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs))*vi - sum(bs for bs in values(bus_bs))*vr
                                - sum(gf for gf in values(bus_gf))*vi 
                                )
end


""
function constraint_gen_fault_voltage_drop(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    gen = ref(pm, nw, :gen, i)
    busid = gen["gen_bus"]
    gen_bus = ref(pm, nw, :bus, busid)

    r = 0
    x = 0.1
    x = 1 # powerworld default
   
   if haskey(gen, "rg")
        r = gen["rg"]
   end

    if haskey(gen, "xg")
        x = gen["xg"]
    end   

    vm = ref(pm, :bus, busid, "vm") 
    va = ref(pm, :bus, busid, "va")
    v = vm*exp(1im*pi*va/180)
    vgr = real(v)
    vgi = imag(v)    

    constraint_gen_fault_voltage_drop(pm, nw, i, busid, r, x, vgr, vgi)
end


"""
Defines voltage drop over a branch, linking from and to side complex voltage
"""
function constraint_gen_fault_voltage_drop(pm::AbstractIVRModel, n::Int, i, busid, r, x, vr_fr, vi_fr)
    vr_to = var(pm, n, :vr, busid)
    vi_to = var(pm, n, :vi, busid)

    # need generator currents
    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)    

    JuMP.@constraint(pm.model, vr_to == vr_fr - r*crg + x*cig)
    JuMP.@constraint(pm.model, vi_to == vi_fr - r*cig - x*crg)
end


function add_fault!(net, busid; resistance=0.1)
    if !("fault" in keys(net))
        net["fault"] = Dict()
    end

    gf = max(1/resistance, 1e-6)
    n = length(keys(net["fault"]))
    i = n + 1
    fault = Dict("source_id"=>Any["fault", i], "bus"=>busid, "gf"=>gf)
    net["fault"]["$i"] = fault
end


# TODO: is there a function already that does this??
function update_base!(net, result)
    s = result["solution"]

    for (k,b) in net["bus"]
        b["vm"] = s["bus"][k]["vm"]
        b["va"] = s["bus"][k]["va"]        
    end 

    # don't really need this
    for (k,g) in net["gen"]
        g["pg"] = s["gen"][k]["pg"]
        g["qg"] = s["gen"][k]["qg"]        
    end     
end



# Here's an attempt at a sequential formulation
# It's a little messy with lots of copy n paste
function run_fault_study(file, model_type, solver; kwargs...)
    if typeof(file) <: AbstractString
        file = PowerModels.parse_file(file)
    end

    base_result = run_opf(file, model_type, solver)
    update_base!(file, base_result)
    return run_model(file, PowerModels.IVRPowerModel, solver, build_fault_study; kwargs...)
end

function run_ac_fault_study(file, solver; kwargs...)
    if typeof(file) <: AbstractString
        file = PowerModels.parse_file(file)
    end

    base_result = run_ac_opf(file, solver)
    update_base!(file, base_result)
    return run_model(file, PowerModels.IVRPowerModel, solver, build_fault_study; kwargs...)
end

function run_dc_fault_study(file, solver; kwargs...)
    if typeof(file) <: AbstractString
        file = PowerModels.parse_file(file)
    end

    base_result = run_dc_opf(file, solver)
    update_base!(file, base_result)
    return run_model(file, PowerModels.IVRPowerModel, solver, build_fault_study; kwargs...)
end

path = "data/b4fault.m"
# path = "data/case30fault.m"
# path = "data/case30.m"
# path = "data/case30.raw"
# path = "data/uiuc-150bus.RAW"
# path = "data/GO500v2_perfect_0.raw"
# path = "data/SDET700Bus.raw"
# path = "data/GO3000_new_perfect.raw"
# path = "data/SDET_2316bus model.raw"
# path = "data/ACTIVSg10k.RAW"
path = "data/B7FaultExample.raw"
# pm = PowerModels.instantiate_model(path, PowerModels.IVRPowerModel, build_fault_study)

# path = "data/case73.raw"
net = PowerModels.parse_file(path)
net["multinetwork"] = false

solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)
# net["fault"]["1"] = Dict("source_id"=>Any["fault", 1], "bus"=>13404, "gf"=>10)


base_result = run_dc_opf(net, solver)
fault_net = deepcopy(net)

update_base!(fault_net, base_result)
add_fault!(fault_net, 3)

result = run_dc_fault_study(fault_net, solver)

for (i,b) in net["bus"]
    kvll = b["base_kv"]
    vbase = 1000*kvll/sqrt(3)
    bs = result["solution"]["bus"][i]
    b["vm"] = [abs(v)*1 for v in bs["vr"] + 1im*bs["vi"]]
end


for (k,br) in net["branch"]
    j = br["t_bus"]
    b = net["bus"]["$j"]
    kvll = b["base_kv"]
    ibase = net["baseMVA"]*1000*sqrt(3)/kvll
    brs = result["solution"]["branch"]["$k"]

    br["ckt"] = strip(br["source_id"][4])
    br["cm_fr"] = [abs(c)*1 for c in brs["cr_fr"] + 1im*brs["ci_fr"]]
    br["cm_to"] = [abs(c)*1 for c in brs["cr_to"] + 1im*brs["ci_to"]]
end

buses = to_df(net, "bus", result)
branches = to_df(net, "branch", result)

# buses[!,[:index,:name,:vr,:vi]]
branches[!,[:f_bus,:t_bus,:ckt,:cm_fr]]