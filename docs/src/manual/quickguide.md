# Quick Start Guide

Once PowerModelsProtection is installed, Ipopt is installed, and a network data file (_e.g._, `"case5_fault.m"` in the package folder under `./test/data/trans`) has been acquired, a short-circuit solve can be executed with,

```julia
using PowerModelsProtection
using Ipopt

ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-6)
case5_fault = parse_file("case5_fault.m")
add_fault!(case5_fault, 1, 2, 0.0001)
result = solve_fault_study(case5_fault, ipopt_solver)
```

## Adding Faults

To add a fault, use the `add_fault!` command

### Transmission

```julia
case5 = parse_file("case5_fault.m")
add_fault!(case5, 1, 2, 0.0001)
```

### Distribution

```julia
case3_balanced_pv = parse_file("case3_balanced_pv.dss"))
add_fault!(data, "testfault", "lg", "loadbus", [1,4], 0.001)
```

## Getting Results

To perform a short-circuit solve, use the `solve_fault_study` or `solve_mc_fault_study` command

### Transmission

```julia
result = solve_fault_study(case5, ipopt_solver)
```

### Distribution

```julia
result = solve_mc_fault_study(case3_balanced_pv, ipopt_solver)
```

## Examples

More examples of working with the engineering data model can be found in the `/examples` folder of the PowerModelsProtection.jl repository. These are Pluto Notebooks; instructions for running them can be found in the [Pluto documentation](https://github.com/fonsp/Pluto.jl#readme)
