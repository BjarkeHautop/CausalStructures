Triggering an ERROR seems to make Julia broken after? Anyway to make it less
brittle? Something like this happens:

Error: ! Evaluation in Julia failed. Original Julia error message: MethodError:
no method matching enumerate_mags(::CausalStructures.MPDAG) The function
`enumerate_mags` exists, but no method is defined for this combination of
argument types.

Closest candidates are: enumerate_mags(!Matched::CausalStructures.PAG) @
CausalStructures
\~/GitHub/testpkg/CausalStructures.jl/src/transform/enumerate-mags.jl:36

Stacktrace: [1] \_testpkg_enumerate_mags(g::CausalStructures.MPDAG) @ Main
./string:78 [2] evaluate!(call::Main.RConnector.Call,
communicator::Main.RConnector.CommunicatoR{Sockets.TCPSocket}) @ Main.RConnector
\~/R/x86_64-pc-linux-gnu-library/4.6/JuliaConnectoR/Julia/evaluating.jl:67 [3]
evaluate_checked!(call::Main.RConnector.Call,
communicator::Main.RConnector.CommunicatoR{Sockets.TCPSocket}) @ Main.RConnector
\~/R/x86_64-pc-linux-gnu-library/4.6/JuliaConnectoR/Julia/evaluating.jl:55 [4]
serve_repl(sock::Sockets.TCPSocket) @ Main.RConnector
\~/R/x86_64-pc-linux-gnu-library/4.6/JuliaConnectoR/Julia/communicating.jl:205
[5] serve(port_hint::Int64; multiclient::Bool, portfile::String) @
Main.RConnector
\~/R/x86_64-pc-linux-gnu-library/4.6/JuliaConnectoR/Julia/communicating.jl:159
[6] top-level scope @
\~/R/x86_64-pc-linux-gnu-library/4.6/JuliaConnectoR/Julia/main.jl:23 [7]
include(mod::Module, \_path::String) @ Base ./Base.jl:306 [8]
exec_options(opts::Base.JLOptions) @ Base ./client.jl:317 [9] \_start() @ Base
./client.jl:550

Show Traceback
