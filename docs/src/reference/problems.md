# [Problems](@id ProblemAPI)

## Solvers

```@autodocs
Modules = [PowerModelsProtection]
Private = false
Order = [:function]
Filter = t -> startswith(string(t), "solve")
```

## Builders

```@autodocs
Modules = [PowerModelsProtection]
Private = false
Order = [:function]
Filter = t -> startswith(string(t), "build")
```

## Solution Helpers

```@autodocs
Modules = [PowerModelsProtection]
Private = false
Order = [:function]
Filter = t -> startswith(string(t), "sol_")
```

## DEPRECIATED Solver functions

```@autodocs
Modules = [PowerModelsProtection]
Private = false
Order = [:function]
Filter = t -> startswith(string(t), "run")
```
