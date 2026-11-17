# Meta-analysis of continuous outcomes from group means and SDs (metafor)

sn_meta_continuous_label <- c(SMD = "Standardized mean difference", MD = "Mean difference")

codegen_meta_continuous <- function(o, meta, ctx) {
  escalc <- paste0("metafor::escalc(measure = ", sn_lit(o$measure), ", n1i = ", sn_name(o$n1), ", m1i = ", sn_name(o$mean1), ", sd1i = ", sn_name(o$sd1),
                   ", n2i = ", sn_name(o$n2), ", m2i = ", sn_name(o$mean2), ", sd2i = ", sn_name(o$sd2), ", data = d, slab = study_label)")
  list(code = sn_meta_code(o, meta, ctx, c(o$study, o$n1, o$mean1, o$sd1, o$n2, o$mean2, o$sd2), escalc, sn_meta_continuous_label[[o$measure]], FALSE),
       assemble = function(env, o, ctx) sn_meta_assemble(env, o, ctx, sn_meta_continuous_label[[o$measure]], FALSE))
}
