@testset "balance fault study" begin
    @testset "3-bus case" begin
        result = FS.run_mc_fault_study("../test/data/dist/ut_trans_2w_yy.dss", ipopt_solver)
    end 
end 