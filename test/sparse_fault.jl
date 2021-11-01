@testset "Unbalanced sparse fault study" begin
    cases = Dict(
        "ut_trans_2w_yy_fault_study" => parse_file("../test/data/dist/ut_trans_2w_yy_fault_study.dss"),
        "case3_balanced_pv" => parse_file("../test/data/dist/case3_balanced_pv.dss"),
        "case3_balanced_pv_grid_forming" => parse_file("../test/data/dist/case3_balanced_pv_grid_forming.dss"),
        "case3_balanced_multi_pv_grid_following" => parse_file("../test/data/dist/case3_balanced_multi_pv_grid_following.dss"),
        "case3_balanced_parallel_pv_grid_following" => parse_file("../test/data/dist/case3_balanced_parallel_pv_grid_following.dss"),
        "case3_balanced_single_phase" => parse_file("../test/data/dist/case3_balanced_single_phase.dss"),
        "case3_unblanced_switch" => parse_file("../test/data/dist/case3_unbalanced_switch.dss"),
        "simulink_model" => parse_file("../test/data/dist/simulink_model.dss"),
    )

    for (_,d) in cases
        # to avoid having to rewrite unit tests for updated default sbase
        d["settings"]["sbase_default"] = 1e3
    end

    @testset "ut_trans_2w_yy_fault_study test fault study" begin
        data = deepcopy(cases["ut_trans_2w_yy_fault_study"])

        fault_study = build_mc_sparse_fault_study(data)    
        sol = solve_mc_fault_study(data, fault_study, ipopt_solver)

        @test collect(keys(sol)) == ["1", "2", "3"]

        @test sol["3"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["3"]["lg"]["1"]["solution"]["line"]["line1"]["cr_to"][1], -179.916) < 0.05
        @test calculate_error_percentage(sol["3"]["lg"]["1"]["solution"]["line"]["line1"]["ci_to"][1], 202.797) < 0.05

        @test sol["3"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["3"]["ll"]["1"]["solution"]["line"]["line1"]["cr_to"][1], -204.191) < 0.05
        @test calculate_error_percentage(sol["3"]["ll"]["1"]["solution"]["line"]["line1"]["ci_to"][1], 52.767) < 0.05        

        @test sol["3"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["3"]["3p"]["1"]["solution"]["line"]["line1"]["cr_to"][1], -175.321) < 0.05
        @test calculate_error_percentage(sol["3"]["3p"]["1"]["solution"]["line"]["line1"]["ci_to"][1], 170.779) < 0.05        
    end

    @testset "3-bus pv fault test single faults" begin
        data = deepcopy(cases["case3_balanced_pv"])

        fault_study = build_mc_sparse_fault_study(data)    
        sol = solve_mc_fault_study(data, fault_study, ipopt_solver)

        @test collect(keys(sol)) == ["loadbus", "pv_bus"]

        @test sol["pv_bus"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["lg"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1],  873.690) < 0.05

        @test sol["pv_bus"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["ll"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 1279.155) < 0.05

        @test sol["pv_bus"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["3p"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 1502.666) < 0.05
    end

    @testset "c3-bus multiple pv grid_following fault test" begin
        data = deepcopy(cases["case3_balanced_multi_pv_grid_following"])

        fault_study = build_mc_sparse_fault_study(data)    
        sol = solve_mc_fault_study(data, fault_study, ipopt_solver)

        @test collect(keys(sol)) == ["pv2_bus", "loadbus", "pv_bus"]

        @test sol["pv_bus"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["lg"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 849.392) < 0.05

        @test sol["pv_bus"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["ll"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 1252.756) < 0.05

        @test sol["pv_bus"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["3p"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 1483.725) < 0.05
    end

    @testset "c3-bus parallel pv grid_following fault test" begin
        data = deepcopy(cases["case3_balanced_parallel_pv_grid_following"])

        fault_study = build_mc_sparse_fault_study(data)    
        sol = solve_mc_fault_study(data, fault_study, ipopt_solver)

        @test collect(keys(sol)) == ["loadbus", "pv_bus"]

        @test sol["pv_bus"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["lg"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 859.242) < 0.05

        @test sol["pv_bus"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["ll"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 1268.365) < 0.05

        @test sol["pv_bus"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["3p"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 1501.912) < 0.05
    end

    @testset "case3 single phase test" begin
        cases["case3_balanced_single_phase"]["voltage_source"]["source"]["grid_forming"] = true
        data = deepcopy(cases["case3_balanced_single_phase"])

        fault_study = build_mc_sparse_fault_study(data)
        sol = solve_mc_fault_study(data, fault_study, ipopt_solver)

        @test collect(keys(sol)) == ["loadbus2", "pv_bus"]

        @test sol["loadbus2"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["loadbus2"]["lg"]["1"]["solution"]["line"]["ohline2"]["cr_to"][1], 515.844) < 0.05
        @test calculate_error_percentage(sol["loadbus2"]["lg"]["1"]["solution"]["line"]["ohline2"]["ci_to"][1], 396.513) < 0.05
        
        @test sol["pv_bus"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["pv_bus"]["lg"]["1"]["solution"]["line"]["pv_line"]["cr_to"][1], 777.992) < 0.05
        @test calculate_error_percentage(sol["pv_bus"]["lg"]["1"]["solution"]["line"]["pv_line"]["ci_to"][1], -428.974) < 0.05
    end

    @testset "case3_unblanced_switch test fault study" begin
        data = deepcopy(cases["case3_unblanced_switch"])

        fault_study = build_mc_sparse_fault_study(data)    
        sol = solve_mc_fault_study(data, fault_study, ipopt_solver)

        @test collect(keys(sol)) == ["primary", "switchbus", "loadbus"]

        @test sol["primary"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["primary"]["lg"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 1847.412) < 0.05

        @test sol["primary"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["primary"]["ll"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 2698.033) < 0.05

        @test sol["primary"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["primary"]["3p"]["1"]["solution"]["line"]["ohline"]["cf_fr"][1], 3178.410) < 0.05
    end
end
