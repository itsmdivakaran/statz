# Agglomerative hierarchical clustering (stats::hclust)

codegen_cluster_hier <- function(o, meta, ctx) {
  k <- as.integer(o$k)
  e <- ctx$plot_engine
  code <- sn_code(
    if (length(o$plot)) sn_libs(e),
    "",
    paste0("# Hierarchical clustering (", o$linkage, " linkage, ", o$distance, " distance), cut into ", k, " clusters"),
    sn_cluster_prep_code(o, ctx, o$label),
    paste0("hc <- hclust(dist(x, method = ", sn_lit(o$distance), "), method = ", sn_lit(o$linkage), ")"),
    paste0("cluster <- factor(cutree(hc, k = ", k, "))"),
    sn_cluster_summary_code(),
    "agglomerative_coef <- cluster::coef.hclust(hc)",
    if ("dendrogram" %in% o$plot) c(
      "# Dendrogram segments from the merge history",
      "n <- length(hc$order)",
      "leaf_x <- match(seq_len(n), hc$order)",
      "node_x <- numeric(n - 1)",
      "segs <- vector(\"list\", n - 1)",
      "for (i in seq_len(n - 1)) {",
      "  child <- hc$merge[i, ]",
      "  cx <- ifelse(child < 0, leaf_x[abs(child)], node_x[abs(child)])",
      "  cy <- ifelse(child < 0, 0, hc$height[abs(child)])",
      "  node_x[i] <- mean(cx)",
      "  segs[[i]] <- data.frame(x = c(cx[1], cx[2], cx[1]), xend = c(cx[1], cx[2], cx[2]), y = c(cy[1], cy[2], hc$height[i]), yend = hc$height[i])",
      "}",
      "dendro <- do.call(rbind, segs)",
      paste0("cut_height <- mean(rev(hc$height)[c(", k - 1, ", ", k, ")])   # height that gives ", k, " clusters"),
      sn_gg(e, "dendro, aes(x = x, y = y, xend = xend, yend = yend)", c("geom_segment()", sn_ref_line(e, "h", "cut_height")),
            "Dendrogram", "Cases", "Height", "p_dendrogram")),
    if ("clusters" %in% o$plot) sn_cluster_plot_code(e)
  )
  list(code = code, assemble = assemble_cluster_hier)
}

assemble_cluster_hier <- function(env, o, ctx) {
  s <- env$silhouette_avg; sz <- env$sizes
  tables <- sn_cluster_tables(env, o)
  if (length(o$label) && nrow(env$d) <= 200) {
    members <- tapply(rownames(env$x), env$cluster, paste, collapse = ", ")
    tables <- c(tables, list(sn_table("members", "Cluster Members", list(sn_col("cluster", "Cluster", "text"), sn_col("members", "Members", "text")),
      data.frame(cluster = names(members), members = as.vector(members), stringsAsFactors = FALSE))))
  }
  tables <- c(tables, list(sn_tbl_wide("fit", "Cluster Solution",
    list(sn_col("k", "k", "int"), sn_col("ac", "Agglomerative coefficient", digits = 3), sn_col("sil", "Average silhouette", digits = 3)),
    list(k = nrow(sz), ac = env$agglomerative_coef, sil = s))))
  text <- sprintf("Hierarchical clustering (%s linkage, %s distance) of %d cases was cut into %d clusters of sizes %s. The agglomerative coefficient was %s, and the average silhouette width of %s indicates %s cluster structure.",
    c(ward.D2 = "Ward", complete = "complete", average = "average", single = "single")[[o$linkage]], o$distance, nrow(env$d), nrow(sz),
    paste(sz$n, collapse = ", "), fmt_num(env$agglomerative_coef, 2), fmt_num(s, 2), sn_silhouette_text(s))
  sn_result(tables = tables, plots = sn_plots(env, ctx, c(p_dendrogram = "Dendrogram", p_clusters = "Cluster plot")), interpretation = text)
}
