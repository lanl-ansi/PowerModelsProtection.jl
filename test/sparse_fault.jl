@testset "Unbalanced sparse fault study" begin
    ut_trans_2w_yy_fault_study = parse_file("../test/data/dist/ut_trans_2w_yy_fault_study.dss")
    case3_balanced_pv = parse_file("../test/data/dist/case3_balanced_pv.dss")
    case3_balanced_pv_grid_forming = parse_file("../test/data/dist/case3_balanced_pv_grid_forming.dss")
    case3_balanced_multi_pv_grid_following = parse_file("../test/data/dist/case3_balanced_multi_pv_grid_following.dss")
    case3_balanced_parallel_pv_grid_following = parse_file("../test/data/dist/case3_balanced_parallel_pv_grid_following.dss")
    case3_balanced_single_phase = parse_file("../test/data/dist/case3_balanced_single_phase.dss")
    case3_unblanced_switch = parse_file("../test/data/dist/case3_unbalanced_switch.dss")
    simulink_model = parse_file("../test/data/dist/simulink_model.dss")

    @testset "ut_trans_2w_yy_fault_study test fault study" begin
        data = deepcopy(ut_trans_2w_yy_fault_study)

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

    #     fault_studies = build_mc_fault_study(data)
    #     sol = solve_mc_fault_study(data, fault_studies, ipopt_solver)

    #     @test sol["1"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["1"]["lg"]["1"]["solution"]["line"]["line1"]["cf_fr"][1], 1381.0) < 0.05
    #     @test sol["1"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["1"]["ll"]["1"]["solution"]["line"]["line1"]["cf_fr"][1], 818.0) < 0.05
    #     @test sol["1"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["1"]["3p"]["1"]["solution"]["line"]["line1"]["cf_fr"][1], 945.0) < 0.05
    end

    # @testset "ut_trans_2w_yy_fault_study line to ground fault" begin
    #     data = deepcopy(ut_trans_2w_yy_fault_study)

    #     add_fault!(data, "1", "lg", "3", [1,4], .00001)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["line"]["line2"]["cf_fr"][1], 785.0) < 0.05
    # end

    # @testset "ut_trans_2w_yy_fault_study 3-phase fault" begin
    #     data = deepcopy(ut_trans_2w_yy_fault_study)

    #     add_fault!(data, "1", "3p", "3", [1,2,3], 0.005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["line"]["line2"]["cf_fr"][1], 708.0) < 0.05
    # end

    # @testset "3-bus pv fault test single faults" begin
    #     data = deepcopy(case3_balanced_pv)

    #     add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.686) < 0.05
    #     add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 38.978) < 0.05

    #     add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.693) < 0.05

    #     # test the current limit bu placing large load to force off limits
    #     add_fault!(data, "1", "3p", "loadbus", [1,2,3], 500.0)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 35.523) < 0.05
    # end

    # @testset "c3-bus multiple pv grid_following fault test" begin
    #     data = deepcopy(case3_balanced_multi_pv_grid_following)

    #     add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "lg", "pv_bus", [1, 4], 0.0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    # end

    # @testset "c3-bus parallel pv grid_following fault test" begin
    #     data = deepcopy(case3_balanced_parallel_pv_grid_following)

    #     add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "lg", "pv_bus", [1, 4], 0.0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    # end

    # @testset "c3-bus pv grid_forming fault test island" begin
    #     case3_balanced_pv_grid_forming["solar"]["pv1"]["grid_forming"] = true
    #     case3_balanced_pv_grid_forming["line"]["ohline"]["status"] = DISABLED

    #     data = deepcopy(case3_balanced_pv_grid_forming)

    #     add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED

    #     add_fault!(data, "1", "lg", "pv_bus", [1, 4], 0.005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    # end

    @testset "case3 single phase test" begin
        case3_balanced_single_phase["voltage_source"]["source"]["grid_forming"] = true
        data = deepcopy(case3_balanced_single_phase)

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

    # @testset "case3_unblanced_switch test fault study" begin
    #     data = deepcopy(case3_unblanced_switch)

    #     add_fault!(data, "1", "3p", "loadbus", [1,2,3], .0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 1454.0) < .06

    #     add_fault!(data, "1", "ll", "loadbus", [1, 2], .0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 1257.0) < .06

    #     add_fault!(data, "1", "lg", "loadbus", [1, 4], .0005)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 883.0) < .06
    # end


    # @testset "compare to simulink model" begin
    #     # TODO needs helper function
    #     simulink_model["solar"]["pv1"]["grid_forming"] = true
    #     simulink_model["line"]["cable1"]["status"] = DISABLED
    #     data = deepcopy(simulink_model)

    #     add_fault!(data, "1", "3p", "midbus", [1,2,3], 60.0)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 13.79) < 0.05

    #     add_fault!(data, "1", "ll", "midbus", [1, 2], 40.0)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 11.94) < 0.05

    #     add_fault!(data, "1", "lg", "midbus", [1, 4], 20.0)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 13.79) < 0.05

    #     add_fault!(data, "1", "3p", "midbus", [1,2,3], .1)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 69.93) < .15

    #     add_fault!(data, "1", "ll", "midbus", [1, 2], .1)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 60.55) < .15

    #     add_fault!(data, "1", "lg", "midbus", [1, 4], .1)
    #     sol = solve_mc_fault_study(data, ipopt_solver)
    #     @test sol["termination_status"] == LOCALLY_SOLVED
    #     @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 103.4) < .15
    # end

end
