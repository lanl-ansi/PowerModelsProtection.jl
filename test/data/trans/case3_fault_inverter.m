% used in tests of,
% - non-contiguous bus ids
% - tranformer orentation swapping
% - dual values
% - clipping cost functions using ncost
% - linear objective function

function mpc = case5_fault
mpc.version = '2';
mpc.baseMVA = 100.0;

%% bus data
%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
mpc.bus = [
	2	 1	 300.0	 98.61	 0.0	 0.0	 1	    1.08407	   -0.73465	 230.0	 1	    1.10000	    0.90000;
	3	 2	 300.0	 98.61	 0.0	 0.0	 1	    1.00000	   -0.55972	 230.0	 1	    1.10000	    0.90000;
	4	 3	 400.0	 131.47	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;	
];

%% generator data
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin
mpc.gen = [
	3	 324.498	 390.000	 390.0	 -390.0	 1.10000	 100.0	 1	 520.0	 0.0;
	4	 000.000     -10.802	 150.0	 -150.0	 1.06414	 100.0	 1	 200.0	 0.0;	
];

%% generator cost data
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	 0.0	 0.0	 3	   0.000000	  30.000000	   0.000000	   2.000000;
	2	 0.0	 0.0	 3	   0.000000	  40.000000	   0.000000	   2.000000;	
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
	2	 3	 0.00108	 0.0108	 0.01852	 4260	 4260	 4260	 0.0	  0.0	 1	 -30.0	 30.0;
	3	 4	 0.00297	 0.0297	 0.00674	 4260	 4260	 4260	 1.05	  1.0	 1	 -30.0	 30.0;	
];

%% generator fault data
%column_names% zr	zx	inverter inverter_mode
mpc.gen_fault = [
	0.05		0.00	1	'pq';
	0.00		0.15	0	'';
];
