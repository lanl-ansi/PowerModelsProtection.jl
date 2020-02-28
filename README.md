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
