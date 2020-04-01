# PowerModelsProtection

Fault study for PowerModels and PowerModelsDistribution
In the future this will also include optimal protection coordation formulations and possibly also protection coordination constraints for optimal switching problems

## Modeling Assumptions

* Generators are modeled as voltage sources behind an impedance. For synchronous generation, this is the subtransient reactance $X_d''$. For inverters, this is currently a virtual resistance. A more accurate model for inverters will take into account their
current limits
* Loads are neglected
* Faults are modeled as an admittance matrix

## TODO

In roughly decreasing order of priority

- [x] Finish mc implementation
- [x] Add LLG faults to add_fault! function
- [x] Set reference bus as constant voltage. Only want to do this for grid connected cases. 
- [x] Read Rg and Xg from PTI RAW33
- [x] How to disable the reference bus constraint for islanded microgrids? - Just set reference buses to PQ or PV
- [x] Convenience function to enumerate faults over all nodes
- [x] Add unit tests for B7Fault
- [x] Push to lanl-ansi/PowerModelsFaultStudy.jl
- [x] Sequential powerflow -> fault study formulation?
- [x] Convenience function to add faults, particularly for unbalanced faults?
- [ ] Finish adding unit tests for modified IEEE 34-bus 
- [ ] Add LICENSE.md - check with Russell first on this
- [ ] Use strings instead of ints for indexing faults in solution. JSON only supports string keys for dict objects
- [ ] Inverter interfaced generation/storage
- [ ] Handle delta-connected generators, this should just be multiplying Xg'' by 3
- [ ] Add "status" field to fault objects
- [ ] change "bus" field in fault objects to "fault_bus" to follow PowerModels conventions
- [ ] Parse OpenDSS fault objects in PowerModelsDistribution/io/parse_pmd.jl
- [ ] Calculate operation times for supported protection devices in solution_builder 
- [ ] Induction motor contribution during faults
- [ ] Transformer winding faults
- [ ] Add unit tests for Kersting IEEE 13-bus fault study


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

## License

This code is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, LA-CC-13-108.
