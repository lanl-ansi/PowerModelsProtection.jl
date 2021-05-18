# Fault Models

This document describes the fault data models, and their mathematical formulations.

## Transmission

This section describes the data model for faults under the transmission schema, i.e. when using `solve_fault_study`.

| Name         | Default | Type     | Units | Used   | Description                                                                                           |
|--------------|---------|----------|-------|--------|-------------------------------------------------------------------------------------------------------|
| `fault_bus`  |         | `String` |       | always | id of bus connection                                                                                  |
| `g`          |         | `Real`   |       | always | Fault conductance                                                                                     |
| `b`          | `0.0`   | `Real`   |       | always | Fault susceptance                                                                                     |
| `status`     | `1`     | `Int`    |       | always | `1` or `0`. Indicates if component is enabled or disabled, respectively                               |
| `fault_type` |         | `String` |       |        | Metadata field that helps users quickly identify type of fault `\in ["lg", "ll", "llg", "3p", "3pg"]` |


## Distribution

This section describes the data models for the distribution


### `ENGINEERING` data model (user-facing)

| Name          | Default                          | Type           | Units   | Used   | Description                                                                                           |
|---------------|----------------------------------|----------------|---------|--------|-------------------------------------------------------------------------------------------------------|
| `bus`         |                                  | `String`       |         | always | id of bus connection                                                                                  |
| `connections` |                                  | `Vector{Int}`  |         | always | Ordered list of connected conductors, `size=nconductors`                                              |
| `g`           |                                  | `Matrix{Real}` | Siemens | always | Fault conductance matrix, `size=(nconductors,nconductors)`                                            |
| `b`           | `zeros(nconductors,nconductors)` | `Matrix{Real}` | Siemens | always | Fault susceptance matrix, `size=(nconductors,nconductors)`                                            |
| `status`      | `ENABLED`                        | `Status`       |         | always | `ENABLED` or `DISABLED`. Indicates if component is enabled or disabled, respectively                  |
| `fault_type`  |                                  | `String`       |         |        | Metadata field that helps users quickly identify type of fault `\in ["lg", "ll", "llg", "3p", "3pg"]` |

### `MATHEMATICAL` data model (internal)

| Name          | Default                          | Type           | Units    | Used   | Description                                                             |
|---------------|----------------------------------|----------------|----------|--------|-------------------------------------------------------------------------|
| `fault_bus`   |                                  | `Int`          |          | always | id of bus connection                                                    |
| `connections` |                                  | `Vector{Int}`  |          | always | Ordered list of connected conductors, `size=nconductors`                |
| `g`           |                                  | `Matrix{Real}` | per-unit | always | Fault conductance matrix, `size=(nconductors,nconductors)`              |
| `b`           | `zeros(nconductors,nconductors)` | `Matrix{Real}` | per-unit | always | Fault susceptance matrix, `size=(nconductors,nconductors)`              |
| `status`      | `1`                              | `Int`          |          | always | `1` or `0`. Indicates if component is enabled or disabled, respectively |

## Formulation
