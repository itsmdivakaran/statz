# Helpers shared by multivariate modules (PCA, factor analysis, clustering) ----

#' Table from a numeric matrix: one text column of row names, one column per matrix column.
#' @param extra named list of extra numeric columns, e.g. list(Communality = h2).
#' @param cut absolute values below this are left blank.
sn_tbl_matrix <- function(id, title, m, row_label = "", digits = 3, extra = list(), cut = 0, notes = character(), type = "number") {
  m <- as.matrix(m)
  rows <- data.frame(name = rownames(m) %||% as.character(seq_len(nrow(m))), stringsAsFactors = FALSE)
  cols <- list(sn_col("name", row_label, "text"))
  for (j in seq_len(ncol(m))) {
    v <- unname(m[, j])
    if (cut > 0) v[abs(v) < cut] <- NA
    rows[[paste0("c", j)]] <- v
    cols <- c(cols, list(sn_col(paste0("c", j), colnames(m)[j], type, digits)))
  }
  for (k in seq_along(extra)) {
    rows[[paste0("x", k)]] <- unname(extra[[k]])
    cols <- c(cols, list(sn_col(paste0("x", k), names(extra)[k], digits = digits)))
  }
  sn_table(id, title, cols, rows, notes = notes)
}

#' Code: Kaiser-Meyer-Olkin measure and Bartlett's test of sphericity for the data frame `x`.
sn_factorability_code <- function(x = "x") {
  sn_code(
    "# Sampling adequacy (KMO) and Bartlett's test of sphericity",
    paste0("R <- cor(", x, ")"),
    "Q <- solve(R)",
    "A <- -Q / sqrt(outer(diag(Q), diag(Q)))   # anti-image (partial) correlations",
    "off <- row(R) != col(R)",
    "kmo <- sum(R[off]^2) / (sum(R[off]^2) + sum(A[off]^2))",
    paste0("bartlett_chi <- -(nrow(", x, ") - 1 - (2 * ncol(", x, ") + 5) / 6) * log(det(R))"),
    paste0("bartlett_df <- ncol(", x, ") * (ncol(", x, ") - 1) / 2"),
    "bartlett_p <- pchisq(bartlett_chi, bartlett_df, lower.tail = FALSE)")
}

#' Assumption checks matching sn_factorability_code().
sn_chk_factorability <- function(env) {
  kmo <- sn_get(env, "kmo")
  if (is.null(kmo)) return(list())
  grade <- if (kmo >= 0.8) "good" else if (kmo >= 0.7) "middling" else if (kmo >= 0.6) "mediocre" else "poor"
  p <- env$bartlett_p
  list(
    sn_check("kmo", "Sampling adequacy (KMO)", if (kmo >= 0.6) "ok" else "warn",
      paste0("KMO = ", fmt_num(kmo, 2), " (", grade, "). ", if (kmo >= 0.6) "The correlations are compact enough for this analysis." else "Values below .60 suggest the variables share too little variance."),
      sn_table("kmo", "Kaiser-Meyer-Olkin Measure", list(sn_col("kmo", "KMO", digits = 3)), data.frame(kmo = kmo))),
    sn_check("bartlett", "Bartlett's test of sphericity", if (isTRUE(p < 0.05)) "ok" else "warn",
      if (isTRUE(p < 0.05)) "The variables are correlated enough to be reduced." else "The correlation matrix is close to an identity matrix; reduction is unlikely to help.",
      sn_table("bartlett", "Bartlett's Test of Sphericity", list(sn_col("chi", "χ²", digits = 2), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue")),
               data.frame(chi = env$bartlett_chi, df = as.integer(env$bartlett_df), p = p)))
  )
}

#' Scree plot code for a data frame `df` with columns `x` and `y`.
sn_scree_code <- function(engine, df, x, y, title = "Scree plot", xlab = "Component", ylab = "Eigenvalue", ref = NULL, obj = "p_scree") {
  sn_gg(engine, paste0(df, ", aes(", x, ", ", y, ")"),
        c("geom_line()", "geom_point(size = 3)", if (!is.null(ref)) sn_ref_line(engine, "h", ref)),
        title, xlab, ylab, obj)
}

#' Code: complete cases of `vars` into `d`, numeric matrix `x` (standardized or not).
sn_cluster_prep_code <- function(o, ctx, label = NULL) {
  sn_code(
    paste0("vars <- ", sn_lit(o$vars)),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, vars, drop = FALSE]), , drop = FALSE]"),
    if (isTRUE(o$standardize)) "x <- scale(d[vars])   # z-scores, so every variable counts equally" else "x <- as.matrix(d[vars])",
    if (length(label)) paste0("rownames(x) <- make.unique(as.character(", sn_ref("d", label), "))"))
}

#' Code: cluster sizes, means in the original units and average silhouette width, from factor `cluster`.
sn_cluster_summary_code <- function() {
  sn_code(
    "sizes <- data.frame(cluster = levels(cluster), n = as.vector(table(cluster)))",
    "centers <- aggregate(d[vars], list(cluster = cluster), mean)",
    "sil <- cluster::silhouette(as.integer(cluster), dist(x))",
    "silhouette_avg <- mean(sil[, \"sil_width\"])",
    "sizes$silhouette <- as.vector(tapply(sil[, \"sil_width\"], cluster, mean))")
}

#' Code: scatter of the first two principal components coloured by cluster.
sn_cluster_plot_code <- function(engine, obj = "p_clusters") {
  sn_code(
    "pc <- prcomp(x)",
    "plot_df <- data.frame(PC1 = pc$x[, 1], PC2 = pc$x[, 2], cluster = cluster)",
    "pc_var <- round(100 * pc$sdev^2 / sum(pc$sdev^2), 1)",
    sn_gg(engine, "plot_df, aes(PC1, PC2, color = cluster)", "geom_point(size = 3, alpha = 0.8)", "Clusters on the first two principal components", NULL, NULL, obj),
    paste0(obj, " <- ", obj, " + labs(x = paste0(\"PC1 (\", pc_var[1], \"%)\"), y = paste0(\"PC2 (\", pc_var[2], \"%)\"))"))
}

#' Tables shared by the clustering modules.
sn_cluster_tables <- function(env, o) {
  s <- env$sizes; cn <- env$centers
  m <- as.matrix(cn[, -1, drop = FALSE]); rownames(m) <- paste("Cluster", cn$cluster)
  list(
    sn_table("sizes", "Cluster Sizes", c(list(sn_col("cluster", "Cluster", "text"), sn_col("n", "N", "int")),
        if (!is.null(s$withinss)) list(sn_col("withinss", "Within-cluster SS")), list(sn_col("silhouette", "Mean silhouette", digits = 3))),
      s[, c("cluster", "n", if (!is.null(s$withinss)) "withinss", "silhouette"), drop = FALSE],
      notes = sprintf("N = %d complete cases. Average silhouette width = %s.", sum(s$n), fmt_num(env$silhouette_avg, 3))),
    sn_tbl_matrix("centers", "Cluster Means", m, "Cluster", digits = 2,
      notes = if (isTRUE(o$standardize)) "Means are in the original units; clustering used standardized values.")
  )
}

sn_silhouette_text <- function(s) {
  if (s >= 0.7) "a strong" else if (s >= 0.5) "a reasonable" else if (s >= 0.25) "a weak" else "no substantial"
}
