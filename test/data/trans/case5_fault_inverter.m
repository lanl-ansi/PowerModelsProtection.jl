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
	1	 2	 0.0	 0.0	 0.0	 0.0	 1	    1.00000	    2.80377	 230.0	 1	    1.10000	    0.90000;
	2	 1	 30.00	 9.861	 0.0	 0.0	 1	    1.08407	   -0.73465	 230.0	 1	    1.10000	    0.90000;
	3	 2	 30.00	 9.861	 0.0	 0.0	 1	    1.00000	   -0.55972	 230.0	 1	    1.10000	    0.90000;
	4	 3	 40.00	 13.147	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	10	 2	 0.0	 0.0	 0.0	 0.0	 1	    1.00000	    3.59033	 230.0	 1	    1.10000	    0.90000;
];

%% generator data
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin
mpc.gen = [
	3	 100.0	 50.0	 150.0	 -150.0	 1.1		 100.0	 1	 200.0	 0.0;
];

%% generator cost data
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	 0.0	 0.0	 3	   0.000000	  30.000000	   0.000000	   2.000000;
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
	1	 2	 0.00281	 0.0281	 0.00712	 400.0	 400.0	 400.0	 0.0	  0.0	 1	 -30.0	 30.0;
	1	 4	 0.00304	 0.0304	 0.00658	 426	 426	 426	 0.0	  0.0	 1	 -30.0	 30.0;
	1	 10	 0.00064	 0.0064	 0.03126	 426	 426	 426	 0.0	  0.0	 1	 -30.0	 30.0;
	2	 3	 0.00108	 0.0108	 0.01852	 426	 426	 426	 0.0	  0.0	 1	 -30.0	 30.0;
	3	 4	 0.00297	 0.0297	 0.00674	 426	 426	 426	 1.05	  1.0	 1	 -30.0	 30.0;
	4	 3	 0.00297	 0.0297	 0.00674	 426	 426	 426	 1.05	 -1.0	 1	 -30.0	 30.0;
	4	 10	 0.00297	 0.0297	 0.00674	 240.0	 240.0	 240.0	 0.0	  0.0	 1	 -30.0	 30.0;
];

%% generator fault data
%column_names% zr	zx	inverter pq_mode v_mode
mpc.gen_fault = [
	0	1	1	1	0;
];
