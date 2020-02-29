@testset "balance fault study" begin
    @testset "3-bus case" begin
        result = FS.run_fault_study("../test/data/trans/b4fault.m", ipopt_solver)
    end 
end 