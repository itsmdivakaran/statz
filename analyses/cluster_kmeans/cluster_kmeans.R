# K-means clustering (stats::kmeans)

codegen_cluster_kmeans <- function(o, meta, ctx) {
  k <- as.integer(o$k); ns <- as.integer(o$nstart); seed <- as.integer(o$seed)
  code <- sn_code(
    if (length(o$plot)) sn_libs(ctx$plot_engine),
    "",
    paste0("# K-means clustering with k = ", k, ": ", paste(o$vars, collapse = ", ")),
    sn_cluster_prep_code(o, ctx),
    paste0("set.seed(", seed, ")"),
    paste0("km <- kmeans(x, centers = ", k, ", nstart = ", ns, ", iter.max = 100)"),
    "cluster <- factor(km$cluster)",
    sn_cluster_summary_code(),
    "sizes$withinss <- km$withinss",
    if ("clusters" %in% o$plot) sn_cluster_plot_code(ctx$plot_engine),
    if ("elbow" %in% o$plot) c(
      "# Total within-cluster sum of squares for k = 1 to 10",
      "k_max <- min(10, nrow(unique(x)) - 1)",
      paste0("set.seed(", seed, ")"),
      paste0("elbow <- data.frame(k = seq_len(k_max), wss = sapply(seq_len(k_max), function(k) kmeans(x, k, nstart = ", ns, ", iter.max = 100)$tot.withinss))"),
      sn_gg(ctx$plot_engine, "elbow, aes(k, wss)", c("geom_line()", "geom_point(size = 3)", sn_ref_line(ctx$plot_engine, "v", k)),
            "Elbow plot", "Number of clusters (k)", "Total within-cluster sum of squares", "p_elbow"))
  )
  list(code = code, assemble = assemble_cluster_kmeans)
}

assemble_cluster_kmeans <- function(env, o, ctx) {
  km <- env$km; s <- env$silhouette_avg
  tables <- c(sn_cluster_tables(env, o), list(
    sn_tbl_wide("fit", "Cluster Solution", list(sn_col("k", "k", "int"), sn_col("tot", "Total SS"), sn_col("within", "Within SS"), sn_col("between", "Between SS"),
        sn_col("ratio", "Between / total", digits = 3), sn_col("sil", "Average silhouette", digits = 3)),
      list(k = length(km$size), tot = km$totss, within = km$tot.withinss, between = km$betweenss, ratio = km$betweenss / km$totss, sil = s))))
  text <- sprintf("K-means clustering of %d cases on %d variables produced %d clusters of sizes %s. The clusters accounted for %.1f%% of the total variance, and the average silhouette width of %s indicates %s cluster structure.",
    nrow(env$d), ncol(env$x), length(km$size), paste(km$size, collapse = ", "), 100 * km$betweenss / km$totss, fmt_num(s, 2), sn_silhouette_text(s))
  sn_result(tables = tables, plots = sn_plots(env, ctx, c(p_clusters = "Cluster plot", p_elbow = "Elbow plot")), interpretation = text)
}
