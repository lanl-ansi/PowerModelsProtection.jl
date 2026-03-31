
"list of nodal type elements in the engineering model"
const _dss_node_elements = String[
    "load", "shunt", "generator", "solar", "storage",
]


"list of edge type elements in the engineering model"
const _dss_edge_elements = String[
    "line",
]


const _pmp_dss_node_elements = String[
    "voltage_source",
]


const _pmp_dss_edge_elements = String[
    "transformer", "switch",
]


# "list of all math asset types"
# const pmp_math_asset_types = String[
#     _pmp_math_elements...,
# ]


# "list of all math asset types"
# const pmd_math_asset_types = String[
#     "bus", _math_node_elements..., _math_edge_elements...
# ]


"list of nodal type elements in the ravens model"
const _ravens_node_elements = String[
    "energy_consumer", "shunt_compensator", "rotating_machine", "power_electronics", 
]


"list of edge type elements in the ravens model"
const _ravens_edge_elements = String[
    "conductor", "switch", 
]


"list of edge type elements in the ravens model"
const _pmp_ravens_edge_elements = String[
    "power_transformer",
]

"list of nodal type elements in the ravens model"
const _pmp_ravens_node_elements = String[
    "energy_source", 
]


"list of all ravens asset types for pmp"
const pmp_ravens_asset_types = String[
    "connectivity_node", _pmp_ravens_edge_elements..., _ravens_edge_elements..., _pmp_ravens_node_elements..., _ravens_node_elements...
]

const pmp_dss_asset_types = [
    "bus", _pmp_dss_edge_elements..., _dss_edge_elements..., _pmp_dss_node_elements..., _dss_node_elements...
]



const pmp_dss_connection_node_elements = String[
    "voltage_source", "load", "shunt", "solar", "storage", 
]


const pmp_dss_connection_edge_elements = String[
    "transformer", "switch", "branch"
]


"admittance model"
const _mc_admittance_asset_types = String[
    "line", "voltage_source", "load", "transformer", "shunt", "solar", "storage", "switch", "rotating_machine"
]


