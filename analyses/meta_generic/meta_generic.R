# Meta-analysis of effect sizes with standard errors (metafor)

codegen_meta_generic <- function(o, meta, ctx) {
  log_scale <- o$scale == "log"
  escalc <- paste0("metafor::escalc(measure = \"GEN\", yi = ", sn_name(o$effect), ", sei = ", sn_name(o$se), ", data = d, slab = study_label)")
  list(code = sn_meta_code(o, meta, ctx, c(o$study, o$effect, o$se), escalc, if (log_scale) "Ratio" else "Effect size", log_scale),
       assemble = function(env, o, ctx) sn_meta_assemble(env, o, ctx, if (o$scale == "log") "Ratio" else "Effect size", o$scale == "log"))
}
