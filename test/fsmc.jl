@testset "balance fault study" begin
    @testset "3-bus case" begin
        result = FS.run_mc_fault_study("../test/data/dist/13Bus/IEEE13NodeCkt.dss", ipopt_solver)
    end 
end 