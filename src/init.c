/*
 * The package's own native routines: a thin layer over the compiled
 * CausalStructures.jl library (`csjl`).
 *
 * The library is built at install time against the user's Julia and loaded
 * by setup() with dyn.load(), so it cannot be linked into this shared object.
 * Instead each entrypoint is registered here as the .Call routine
 * `C_<name>`, which forwards to the library's `csjl_r_<name>` through a
 * function pointer that csjl_bind() resolves once the library is loaded.
 */

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* The generic function pointer type, cast to each entrypoint's own type. */
typedef void (*csjl_fn)(void);
typedef void (*csjl_threads_fn)(int *, int *);

/* Argument lists for a routine taking `n` SEXPs. */
#define PARAMS_0 void
#define PARAMS_1 SEXP a1
#define PARAMS_2 PARAMS_1, SEXP a2
#define PARAMS_3 PARAMS_2, SEXP a3
#define PARAMS_4 PARAMS_3, SEXP a4
#define PARAMS_5 PARAMS_4, SEXP a5
#define PARAMS_6 PARAMS_5, SEXP a6
#define PARAMS_7 PARAMS_6, SEXP a7
#define ARGS_0
#define ARGS_1 a1
#define ARGS_2 ARGS_1, a2
#define ARGS_3 ARGS_2, a3
#define ARGS_4 ARGS_3, a4
#define ARGS_5 ARGS_4, a5
#define ARGS_6 ARGS_5, a6
#define ARGS_7 ARGS_6, a7

/* One function pointer per entrypoint, NULL until csjl_bind(). */
#define CSJL_ENTRY(name, n) static SEXP (*fn_##name)(PARAMS_##n) = NULL;
#include "entrypoints.h"
#undef CSJL_ENTRY

static void not_bound(void)
{
    Rf_errorcall(R_NilValue,
                 "The compiled CausalStructures.jl library is not loaded; "
                 "run setup() for details.");
}

/* The library never raises an R error itself, since R's error longjmp would
 * unwind through Julia frames. It returns a failure as a character vector
 * with class `csjl_error` (the only character result that carries a class),
 * which is raised here, after the Julia call has returned. */
static SEXP checked(SEXP res)
{
    if (TYPEOF(res) == STRSXP && Rf_isObject(res))
        Rf_errorcall(R_NilValue, "%s", CHAR(STRING_ELT(res, 0)));
    return res;
}

/* The registered routines. */
#define CSJL_ENTRY(name, n)                                                    \
    static SEXP C_##name(PARAMS_##n)                                           \
    {                                                                          \
        if (fn_##name == NULL)                                                 \
            not_bound();                                                       \
        return checked(fn_##name(ARGS_##n));                                   \
    }
#include "entrypoints.h"
#undef CSJL_ENTRY

static csjl_fn find(const char *dll, const char *symbol)
{
    DL_FUNC f = R_FindSymbol(symbol, dll, NULL);
    if (f == NULL)
        Rf_error("Symbol '%s' not found in the compiled CausalStructures.jl "
                 "library; reinstall CausalStructures to rebuild it.",
                 symbol);
    return (csjl_fn)f;
}

/* Resolve every entrypoint in the loaded library named `dll` (its DLLInfo
 * name). All symbols are looked up before any pointer is set, so a library
 * missing one leaves the package unbound rather than half bound. */
static SEXP C_csjl_bind(SEXP dll)
{
    const char *name = CHAR(STRING_ELT(dll, 0));
#define CSJL_ENTRY(entry, n) csjl_fn found_##entry = find(name, "csjl_r_" #entry);
#include "entrypoints.h"
#undef CSJL_ENTRY
#define CSJL_ENTRY(entry, n)                                                   \
    fn_##entry = (SEXP (*)(PARAMS_##n))found_##entry;
#include "entrypoints.h"
#undef CSJL_ENTRY
    return R_NilValue;
}

/* Set the Julia thread count; must run before the first entrypoint call,
 * which initializes Julia. Returns the status of csjl_set_julia_threads
 * (tools/csjl/src/set_threads.c). */
static SEXP C_csjl_set_threads(SEXP dll, SEXP threads)
{
    csjl_threads_fn f = (csjl_threads_fn)find(CHAR(STRING_ELT(dll, 0)),
                                              "csjl_set_julia_threads");
    int n = Rf_asInteger(threads);
    int status = 0;
    f(&n, &status);
    return Rf_ScalarInteger(status);
}

static const R_CallMethodDef call_methods[] = {
#define CSJL_ENTRY(name, n) {#name, (DL_FUNC)&C_##name, n},
#include "entrypoints.h"
#undef CSJL_ENTRY
    {"csjl_bind", (DL_FUNC)&C_csjl_bind, 1},
    {"csjl_set_threads", (DL_FUNC)&C_csjl_set_threads, 2},
    {NULL, NULL, 0}};

void R_init_CausalStructures(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
