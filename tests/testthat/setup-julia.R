# Shut down the shared Julia session after all tests have run
withr::defer(try(cs_stop(), silent = TRUE), teardown_env())
