# RONM Protection

Repository for protection constraints/fault studies for the RONM project

## Modeling Assumptions

### Balanced
* Generators are modeled as voltage sources behind an impedance. For synchronous generation, this is the subtransient reactance $X_d''$. For inverters, this is currently a virtual resistance. A more accurate model for inverters will take into account their
current limits
* Loads are neglected
* Faults are modeled as a resistance to ground. Any number of faults can be applied simulataneously at the same or different buses

### Unbalanced


## Contents
* ```fault-flat.jl```: Balanced fault study formulation.
* ```fault-flat-unbalanced.jl```: Unbalanced fault study formulation.

## TODO

In roughly decreasing order of priority

- [x] Finish mc implementation
- [x] Add LLG faults to add_fault! function
- [x] Set reference bus as constant voltage. Only want to do this for grid connected cases. 
- [ ] Read Rg and Xg from PTI RAW33
- [ ] How to disable the reference bus constraint for islanded microgrids?
- [ ] Convenience function to enumerate faults over all nodes
- [ ] Add unit tests for B7Fault
- [ ] Add unit tests for Kersting IEEE 13-bus fault study
- [ ] Add LICENSE.md - check with Russell first on this
- [ ] Push to lanl-ansi/PowerModelsFaultStudy.jl
- [ ] Add "status" field to fault objects
- [ ] change "bus" field in fault objects to "fault_bus" to follow PowerModels conventions
- [ ] Parse OpenDSS fault objects in PowerModelsDistribution/io/parse_pmd.jl
- [ ] Inverter interfaced generation/storage
- [ ] Induction motor contribution during faults
- [ ] Transformer winding faults
- [x] Sequential powerflow -> fault study formulation?
- [x] Convenience function to add faults, particularly for unbalanced faults?


## LLG Fault Model
![Wye & Delta Load Configurations](/docs/images/wye-delta.svg)
![Unbalanced Wye to Delta Admittance Conversion](/docs/images/wye-delta-admittance-conversion.svg)


## Inverter Fault Models

### Virtual Resistance Model
vr, vi set from inverter node voltage base power flow
rs = 0.8 pu, gives 1.3 pu current into a short
xs = 0 pu

### Current Limiting Model
vr0, vi0 set from inverter node voltage from base power flow
rs or xs = small number, 0.01 - 0.1
crg0, cig0 set from inverter current injection in base power flow

-cmax <= crg <= cmax
-cmax <= cig <= cmax

Objective is sum((crg[g] - crg0[c])^2 + (cig[g] - cig0[c])^2 for g in inverter_gens)
