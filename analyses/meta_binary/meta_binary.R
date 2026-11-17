# Meta-analysis of binary outcomes from event counts (metafor)

sn_meta_binary_label <- c(RR = "Risk ratio", OR = "Odds ratio", RD = "Risk difference")

codegen_meta_binary <- function(o, meta, ctx) {
  escalc <- paste0("metafor::escalc(measure = ", sn_lit(o$measure), ", ai = ", sn_name(o$events1), ", n1i = ", sn_name(o$n1), ", ci = ", sn_name(o$events2), ", n2i = ", sn_name(o$n2), ", data = d, slab = study_label)")
  list(code = sn_meta_code(o, meta, ctx, c(o$study, o$events1, o$n1, o$events2, o$n2), escalc, sn_meta_binary_label[[o$measure]], o$measure != "RD"),
       assemble = function(env, o, ctx) sn_meta_assemble(env, o, ctx, sn_meta_binary_label[[o$measure]], o$measure != "RD"))
}
