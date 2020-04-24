# PowerModelsProtection

Fault study for PowerModels and PowerModelsDistribution

In the future this will also include optimal protection coordation formulations and possibly also protection coordination constraints for optimal switching problems

## Modeling Assumptions

* Generators are modeled as voltage sources behind an impedance. For synchronous generation, this is the subtransient reactance $X_d''$. For inverters, this is currently a virtual resistance. A more accurate model for inverters will take into account their
current limits
* Loads are neglected
* Faults are modeled as an admittance matrix

## Usage Example (Balanced Case)

```julia
using PowerModels, PowerModelsProtection, Ipopt
net = PowerModels.parse_file("case5.raw", import_all=true)
solver = JuMP.with_optimizer(Ipopt.Optimizer)

net["fault"] = Dict()
net["fault"]["1"] = Dict("bus"=>2, "r"=>0.0001)

results = PowerModelsProtection.run_fault_study(net, solver )
print(results)
```

## TODO

_TODO section has moved to issues_


## LLG Fault Model

![Wye & Delta Load Configurations](/docs/src/assets/wye-delta.svg)
![Unbalanced Wye to Delta Admittance Conversion](/docs/src/assets/wye-delta-admittance-conversion.svg)

## Inverter Fault Models

### Grid-Following Inverter

#### Balanced

1. `k*p = vr*cr - vi*ci`
2. `k*q = vr*ci + vi*cr`

where `k` is a decision variable ranging from 0 to 1

### Unbalanced

An inverter under unbalanced conditions will operate 
at a fixed power factor _averaged across all phases_
while injecting only positive-sequence current. 
This sounds ugly, but the constraints don't appear
to be too bad.

Given
1. `a = ar + ai = exp(j*2*pi/3) = -1/2 + j*sqrt(3/2`
2. `a^2 = a2r + j*a2i = exp(j*4*pi/3) = -1/2 - j*sqrt(3/2`

Positive-sequence current constraints:
1. `car = c1r`
2. `cai = c1i`
3. `cbr = a2r*c1r + a2i*c1i`
4. `cbi = a2r*c1i + a2i*c2r`
5. `ccr = ar*c1r + ai*c1i`
6. `cci = ar*c1i + ai*c1i`

Constant power factor constraints:
1. `k*p = var*car + vbr*cbr + vcr*ccr - vai*cai - vbi*cbi - vci*cci`
2. `k*q = var*cai + vbr*cbi + vcr*cci + vai*car + vbi*cbr + vci*ccr`

### Grid-Forming Inverter

#### Virtual Resistance Model

`vr`, `vi` set from inverter node voltage base power flow
`rs = 0.8 pu`, gives `1.3 pu` current into a short
`xs = 0 pu`

#### Current Limiting Model

This model assumes that 
`vm`, `va` set from inverter node voltage from base power flow

```julia
vr[c] = kg[c]*vm[c]*cos(va[c])
vi[c] = kg[c]*vm[c]*sin(va[c])
-cmax <= crg[c] <= cmax for c in cnds
-cmax <= cig[c] <= cmax for c in cnds
```

Objective is `sum( sum((vr[c] - vm[c]*cos(va[c]))^2 + (vi[c] - vm[c]*sin(va[c]))^2 for c in cnd) for g in inverter_gens)`

#### Current Limiting Model with Droop

Constraints

```
Vg0 = V0 + zg*Ig0
V = kg*Vg0 - Z*Ig
|Ig| <= Igmax
```

Objective is `sum( (vg - vg0)^2 for g in inverter_gens)`

This code is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, LA-CC-13-108.
