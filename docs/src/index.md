# PowerModelsProtection.jl Documentation

```@meta
CurrentModule = PowerModelsProtection
```

## Overview

PowerModelsProtection.jl is a Julia/JuMP extension package to PowerModels.jl and PowerModelsDistribution.jl for modeling of protection coordination on power grids.

## Installation

The latest stable release of PowerModelsProtection can be installed using the Julia package manager with

```julia
Pkg.add(Pkg.PackageSpec(name="PowerModelsProtection", url="https://github.com/lanl-ansi/PowerModelsProtection.jl.git"))
```

For the current development version, "checkout" this package with

```julia
Pkg.develop(Pkg.PackageSpec(name="PowerModelsProtection", url="https://github.com/lanl-ansi/PowerModelsProtection.jl.git"))
```

At least one solver is required for running PowerModelsProtection.  The open-source solver Ipopt is recommended, as it is extremely fast, and can be used to solve a wide variety of the problems and network formulations provided in PowerModelsProtection.  The Ipopt solver can be installed via the package manager with

```julia
Pkg.add("Ipopt")
```

Test that the package works by running

```julia
Pkg.test("PowerModelsProtection")
```
