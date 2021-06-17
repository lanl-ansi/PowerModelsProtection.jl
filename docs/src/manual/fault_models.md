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

### Connection Examples

#### Line-Ground (Phase A)

Connections `connections`: `[1,0]`
Fault admittance matrix `g`:
$$
\begin{bmatrix}
g_f & -g_f \\
-g_f & g_f
\end{bmatrix}
$$
Fault admittance matrix `b`:
$$
\begin{bmatrix}
b_f & -b_f \\
-b_f & b_f
\end{bmatrix}
$$

#### Line-Neutral (Ungrounded Neutral, Phase A)

Connections `connections`: `[1,4]`
Fault admittance matrix `g`:
$$
\begin{bmatrix}
g_f & -g_f \\
-g_f & g_f
\end{bmatrix}
$$
Fault admittance matrix `b`:
$$
\begin{bmatrix}
b_f & -b_f \\
-b_f & b_f
\end{bmatrix}
$$

#### Line-Line (Phase A-B)

Connections `connections`: `[1,0]`
Fault admittance matrix `g`:
$$
\begin{bmatrix}
g_f & -g_f \\
-g_f & g_f
\end{bmatrix}
$$
Fault admittance matrix `b`:
$$
\begin{bmatrix}
b_f & -b_f \\
-b_f & b_f
\end{bmatrix}
$$

#### Line-Line-Ground (Phase A-B)

Connections `connections`: `[1,2,0]`
Fault admittance matrix `g`:
$$
\begin{bmatrix}
g_{pg} + g_{pp} & -g_{pp} & -g_{pg} \\
-g_{pp} & g_{pg} + g_{pp} & -g_{pg} \\
-g_{pg} & -g_{pg} & 2g_{pg} \\
\end{bmatrix}
$$
Fault admittance matrix `b`:
$$
\begin{bmatrix}
b_{pg} + b_{pp} & -b_{pp} & -b_{pg} \\
-b_{pp} & b_{pg} + b_{pp} & -b_{pg} \\
-b_{pg} & -b_{pg} & 2b_{pg} \\
\end{bmatrix}
$$

#### Three-Phase Ungrounded

Connections `connections`: `[1,2,3]`
Fault admittance matrix `g`:
$$
3
\begin{bmatrix}
2g_f & -g_f & -g_f\\
-g_f & 2g_f & -g_f \\
-g_f & -g_f & 2g_f\\
\end{bmatrix}
$$
Fault admittance matrix `b`:
$$
3
\begin{bmatrix}
2b_f & -b_f & -b_f\\
-b_f & 2b_f & -b_f \\
-b_f & -b_f & 2b_f\\
\end{bmatrix}
$$

#### Three-Phase Grounded

Connections `connections`: `[1,2,3,0]`
Fault admittance matrix `g`:
$$
\begin{bmatrix}
g_{pg} + 2g_{pp} & -g_{pp} & -g_{pp} & -g_{pg} \\
-g_{pp} & g_{pg} + 2g_{pp} & -g_{pg} & -g_{pg} \\
-g_{pp} & -g_{pp} & g_{pg} + 2g_{pp} & -g_{pg} \\
-g_{pg} & -g_{pg} & -g_{pg} & 3g_{pg}
\end{bmatrix}
$$
Fault admittance matrix `b`:
$$
\begin{bmatrix}
b_{pg} + 2b_{pp} & -b_{pp} & -b_{pp} & -b_{pg} \\
-b_{pp} & b_{pg} + 2b_{pp} & -b_{pg} & -b_{pg} \\
-b_{pp} & -b_{pp} & b_{pg} + 2b_{pp} & -b_{pg} \\
-b_{pg} & -b_{pg} & -b_{pg} & 3b_{pg}
\end{bmatrix}
$$

## Formulation

Depending on fault type, the constraints between
networks are as follows

### LG
$$I_{f1} = I_{f2} = I_{f0} = \frac{V_{f1} + V_{f2} + V_{f0}}{Z_f}$$

### LL
$$I_{f1} = - I_{f2} = \frac{V_{f1} - V_{f2}}{Z_f}$$

### LLG
$$V_{f1} = V_{f2}$$
$$I_{f0} = \frac{V_{f1} - V_{f2}}{Z_f}$$

### 3P
$$I_{f1} = \frac{V_{f1}}{Z_f}$$
$$I_{f2} = I_{f0} = 0$$
