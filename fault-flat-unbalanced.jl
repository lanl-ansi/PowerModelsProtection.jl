using PowerModels, PowerModelsDistribution, JuMP, Ipopt

include("powermodelsio.jl")

const PMs = PowerModels
const PMD = PowerModelsDistribution

""
function run_mc_fault_study(data::Dict{String,Any}, solver; kwargs...)
    return PMs.run_model(data, PMs.IVRPowerModel, solver, build_mc_fault_study; ref_extensions=[ref_add_arcs_trans!], multiconductor=true, kwargs...)
end


""
function run_mc_fault_study(file::String, solver; kwargs...)
    return run_mc_fault_study(PowerModelsDistribution.parse_file(file), PMs.IVRPowerModel, solver; kwargs...)
end


""
function build_mc_fault_study(pm::PMs.AbstractPowerModel)
    # Variables
    PMD.variable_mc_voltage(pm, bounded = false)
    PMD.variable_mc_branch_current(pm, bounded = false)
    PMD.variable_mc_transformer_current(pm, bounded = false)
    PMD.variable_mc_generation(pm, bounded = false) 

    # TODO: Special current balance constraint needed for ref buses?
    # TODO: How to disable ref buses for islanded microgrids?
    for (i,bus) in PMs.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        constraint_mc_ref_bus_voltage(pm, i)
    end    

    # gens should be constrained before KCL, or Pd/Qd undefined
    for id in PMs.ids(pm, :gen)
        PMD.constraint_mc_generation(pm, id)
    end

    for (i,bus) in PMs.ref(pm, :bus)
        # do need a new version to handle gmat
        constraint_mc_fault_current_balance(pm, i)        

        if length(PMs.ref(pm, :bus_gens, i)) > 0 && !(i in PMs.ids(pm,:ref_buses))
            # this assumes inactive generators are filtered out of bus_gens

            for j in ref(pm, :bus_gens, i)
                constraint_mc_gen_fault_voltage_drop(pm, j)
            end
        end        
    end

    for i in PMs.ids(pm, :branch)
        PMD.constraint_mc_current_from(pm, i)
        PMD.constraint_mc_current_to(pm, i)

        PMD.constraint_mc_voltage_drop(pm, i)
    end

    for i in PMs.ids(pm, :transformer)
        PMD.constraint_mc_trans(pm, i)
    end
end

""
function constraint_mc_fault_current_balance(pm::PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = PMs.ref(pm, nw, :bus, i)
    bus_arcs = PMs.ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = PMs.ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = PMs.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = PMs.ref(pm, nw, :bus_gens, i)
    bus_shunts = PMs.ref(pm, nw, :bus_shunts, i)

    bus_faults = []

    # TODO: replace with list comprehension
    for (k,f) in ref(pm, :fault)
        if f["fault_bus"] == i
            push!(bus_faults, k)
            # println("Adding fault $k to bus $i")
        end
    end    

    bus_gs = Dict(k => PMs.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => PMs.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    bus_gf =  Dict(k => ref(pm, nw, :fault, k, "gf") for k in bus_faults)

    constraint_mc_fault_current_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs, bus_gf)
end


"""
Kirchhoff's current law applied to buses
`sum(cr + im*ci) = 0`
"""
function constraint_mc_fault_current_balance(pm::PMs.AbstractIVRModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs, bus_gf)
    vr = PMs.var(pm, n, :vr, i)
    vi = PMs.var(pm, n, :vi, i)

    # TODO: add storage back with inverter fault model
    cr    = get(PMs.var(pm, n),    :cr, Dict()); PMs._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(PMs.var(pm, n),    :ci, Dict()); PMs._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(PMs.var(pm, n),   :crg_bus, Dict()); PMs._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(PMs.var(pm, n),   :cig_bus, Dict()); PMs._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crsw  = get(PMs.var(pm, n),  :crsw, Dict()); PMs._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(PMs.var(pm, n),  :cisw, Dict()); PMs._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(PMs.var(pm, n),   :crt, Dict()); PMs._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(PMs.var(pm, n),   :cit, Dict()); PMs._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    cnds = PMs.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    Gt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_gs))  
    Bt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_bs))

    Gf = isempty(bus_gf) ? fill(0.0, ncnds, ncnds) : sum(values(bus_gf)) # TODO: handle scalar or vector bus_gf

    for c in cnds
        JuMP.@NLconstraint(pm.model,  sum(cr[a][c] for a in bus_arcs)
                                    + sum(crsw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(crt[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                    sum(crg[g][c]        for g in bus_gens)
                                    - sum( Gt[c,d]*vr[d] - Bt[c,d]*vi[d] for d in cnds) # shunts
                                    - sum( Gf[c,d]*vr[d] for d in cnds) # faults
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cisw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                    sum(cig[g][c]        for g in bus_gens)
                                    - sum( Gt[c,d]*vi[d] + Bt[c,d]*vr[d] for d in cnds) # shunts
                                    - sum( Gf[c,d]*vi[d] for d in cnds) # faults
                                    )
    end
end


""
function constraint_mc_gen_fault_voltage_drop(pm::AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    gen = ref(pm, nw, :gen, i)
    busid = gen["gen_bus"]
    gen_bus = ref(pm, nw, :bus, busid)


    r = 0
    x = 0.1
   
   if haskey(gen, "rg")
        r = gen["rg"]
   end

    if haskey(gen, "xg")
        x = gen["xg"]
    end   

    # Watch out! OpenDSS doesn't include base case voltages in input file
    vm = ref(pm, :bus, busid, "vm") 
    va = ref(pm, :bus, busid, "va")

    # Watch out! Angles are in radians unlike in vanilla PowerModels
    v = [vm[i]*exp(1im*va[i]) for i in 1:3]

    vgr = [real(vk) for vk in v]
    vgi = [imag(vk) for vk in v]

    constraint_mc_gen_fault_voltage_drop(pm, nw, i, busid, r, x, vgr, vgi)
end


"""
Defines voltage drop over a branch, linking from and to side complex voltage
"""
function constraint_mc_gen_fault_voltage_drop(pm::AbstractIVRModel, n::Int, i, busid, r, x, vr_fr, vi_fr)
    vr_to = var(pm, n, :vr, busid)
    vi_to = var(pm, n, :vi, busid)

    # need generator currents
    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)    

    cnds = PMs.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    for c in cnds
        JuMP.@constraint(pm.model, vr_to[c] == vr_fr[c] - r*crg[c] + x*cig[c])
        JuMP.@constraint(pm.model, vi_to[c] == vi_fr[c] - r*cig[c] - x*crg[c])
    end
end


""
# PowerModelsDistribution doesn't appear to set reference bus voltages for models using rectangular coordinates
function constraint_mc_ref_bus_voltage(pm::AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    # Watch out! OpenDSS doesn't include base case voltages in input file
    vm = ref(pm, :bus, i, "vm") 
    va = ref(pm, :bus, i, "va")

    # Watch out! Angles are in radians unlike in vanilla PowerModels
    v = [vm[i]*exp(1im*va[i]) for i in 1:3]

    vr = [real(vk) for vk in v]
    vi = [imag(vk) for vk in v]

    constraint_mc_ref_bus_voltage(pm, nw, i, vr, vi)
end


""
function constraint_mc_ref_bus_voltage(pm::AbstractIVRModel, n::Int, i, vr0, vi0)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    cnds = PMs.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    for c in cnds
        JuMP.@constraint(pm.model, vr[c] == vr0[c])
        JuMP.@constraint(pm.model, vi[c] == vi0[c])
    end
end

# create a convenience function add_fault or keyword options to run_mc_fault study
function add_mc_fault!(net, busid; resistance=0.1, phase_resistance=0.01, type="balanced", phases=[1, 2, 3])
    if !("fault" in keys(net))
        net["fault"] = Dict()
    end

    gf = max(1/resistance, 1e-6)
    gp = max(1/phase_resistance, 1e-6)
    Gf = zeros(3,3)

    if lowercase(type) == "lg"
        i = phases[1]

        Gf[i,i] = gf
    elseif lowercase(type) == "ll"
        i = phases[1]
        j = phases[2]

        Gf[i,j] = gf
        Gf[j,i] = gf
    elseif lowercase(type) == "llg"
        i = phases[1]
        j = phases[2]        
        # See https://en.wikipedia.org/wiki/Y-%CE%94_transform
        # Section: Equations for the transformation from Y to Delta
        gtot = 2*gp + gf

        gpp = gp*gp/gtot 
        gpg = gp*gf/gtot

        Gf[i,j] = gpp
        Gf[j,i] = gpp
        Gf[i,i] = gpg
        Gf[j,j] = gpg
    elseif lowercase(type) == "3p" # three-phase ungrounded
        # See http://faculty.citadel.edu/potisuk/elec202/notes/3phase1.pdf p.12
        gpp = gf/3

        for i in 1:3
            for j in 1:3
                if i != j
                    Gf[i,j] = gpp
                end
            end
        end        
    elseif lowercase(type) == "3pg" # three-phase grounded
        # See https://en.wikipedia.org/wiki/Star-mesh_transform
        gtot = 3*gp + gf

        gpp = gp*gp/gtot 
        gpg = gp*gf/gtot

        for i in 1:3
            for j in 1:3
                if i == j
                    Gf[i,j] = gpp
                else
                    Gf[i,j] = gpg
                end
            end
        end
    else # balanced
        for i in 1:3
            Gf[i,i] = gf
        end
    end

        
    n = length(keys(net["fault"]))
    net["fault"]["$(n + 1)"] = Dict("fault_bus"=>busid, "gf"=>Gf, "status"=>1)
end


path = "data/mc/ut_trans_2w_yy.dss"
# path = "data/mc/13Bus/IEEE13NodeCkt.dss"
net = PMD.parse_file(path)
net["fault"] = Dict()

add_mc_fault!(net, 4, resistance=1e-4, type="3pg")

solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)
pmd = PMD.parse_file(path)
sol = PMD.run_mc_pf_iv(pmd, PMs.IVRPowerModel, solver)

result = run_mc_fault_study(net, solver)

for (k,br) in net["branch"]
    j = br["t_bus"]
    b = net["bus"]["$j"]
    kvll = b["base_kv"]
    ibase = net["baseMVA"]*1000*sqrt(3)/kvll
    brs = result["solution"]["branch"]["$k"]

    br["cm_to"] = [abs(x)*ibase for x in brs["cr_to"] + 1im*brs["ci_to"]]
end

buses = to_df(net, "bus", result)
branches = to_df(net, "branch", result)

# buses[!,[:index,:name,:vr,:vi]]
branches[!,[:f_bus,:t_bus,:name,:cm_to,:cr_to]]
