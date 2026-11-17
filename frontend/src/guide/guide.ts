// "Which analysis should I use?" — a decision tree over a few plain questions.
// Pure functions so the logic is unit-tested apart from the dialog.
import type { DataInfo, ModuleSpec, Options, VariableMeta } from "../types";

export type Goal = "compare" | "relate" | "predict" | "describe" | "agreement" | "survival" | "time" | "structure" | "diagnostic" | "meta";
export type Outcome = "continuous" | "ordinal" | "binary" | "nominal" | "count";

export interface Answers {
  goal?: Goal;
  outcome?: Outcome;
  groups?: "one" | "two" | "many";
  design?: "independent" | "paired";
  factors?: "one" | "several";
  normal?: "yes" | "no";
  kind?: "continuous" | "ordinal" | "categorical";
  clustered?: "no" | "yes";
  purpose?: "explain" | "predict";
  survival?: "compare" | "adjust";
  ts?: "explore" | "forecast";
  structure?: "variables" | "latent" | "cases";
  agree?: "items" | "continuous" | "categorical";
  diag?: "binary" | "score";
  meta?: "effects" | "binary" | "continuous";
  describe?: "summary" | "table1";
  approach?: "frequentist" | "bayesian";
}

export interface Choice { value: string; label: string; hint?: string }
export interface Question { id: keyof Answers; text: string; choices: Choice[] }
export interface Pick { module: string; why: string; options?: Options }
export interface Recommendation extends Pick { alternatives: Pick[] }

export const GOALS: Choice[] = [
  { value: "compare", label: "Compare groups or conditions", hint: "Do treated and control differ?" },
  { value: "relate", label: "Relationship between variables", hint: "Is age related to blood pressure?" },
  { value: "predict", label: "Predict or explain an outcome", hint: "Which factors predict relapse?" },
  { value: "describe", label: "Describe or summarise data", hint: "Means, counts, Table 1" },
  { value: "agreement", label: "Reliability or agreement", hint: "Do two raters agree?" },
  { value: "survival", label: "Time until an event", hint: "Survival, time to relapse" },
  { value: "time", label: "Values over time", hint: "Trends, seasonality, forecasts" },
  { value: "structure", label: "Find structure", hint: "Factors, components, clusters" },
  { value: "diagnostic", label: "Diagnostic test accuracy", hint: "Sensitivity, ROC curves" },
  { value: "meta", label: "Combine studies", hint: "Meta-analysis" },
];

const OUTCOME_ALL: Choice[] = [
  { value: "continuous", label: "A measurement", hint: "Blood pressure, score, weight" },
  { value: "ordinal", label: "Ordered categories or ranks", hint: "Likert item, stage I–IV" },
  { value: "binary", label: "Yes / no", hint: "Recovered, died, passed" },
  { value: "nominal", label: "Unordered categories (3+)", hint: "Blood type, region" },
  { value: "count", label: "A count", hint: "Number of visits, seizures" },
];

const Q = {
  outcome: (choices = OUTCOME_ALL): Question => ({ id: "outcome", text: "What is the outcome you measured?", choices }),
  groups: { id: "groups", text: "How many groups or conditions?", choices: [
    { value: "one", label: "One group", hint: "Compare with a known value" },
    { value: "two", label: "Two" }, { value: "many", label: "Three or more" }] } as Question,
  design: { id: "design", text: "Are the groups the same people measured repeatedly?", choices: [
    { value: "independent", label: "No, different people", hint: "Independent groups" },
    { value: "paired", label: "Yes, same people", hint: "Before/after, matched pairs" }] } as Question,
  factors: { id: "factors", text: "How many grouping factors?", choices: [
    { value: "one", label: "One", hint: "Treatment" }, { value: "several", label: "Two or more", hint: "Treatment × sex" }] } as Question,
  normal: { id: "normal", text: "Is the outcome roughly normal (or each group larger than ~30)?", choices: [
    { value: "yes", label: "Yes, or not sure" }, { value: "no", label: "No, skewed or with outliers" }] } as Question,
  kind: { id: "kind", text: "What kind of variables?", choices: [
    { value: "continuous", label: "Both measurements" }, { value: "ordinal", label: "Ranks or ordered categories" },
    { value: "categorical", label: "Both categories" }] } as Question,
  clustered: { id: "clustered", text: "Are observations grouped (repeated measures, patients within clinics)?", choices: [
    { value: "no", label: "No" }, { value: "yes", label: "Yes" }] } as Question,
  purpose: { id: "purpose", text: "What matters most?", choices: [
    { value: "explain", label: "Understand the effects", hint: "Coefficients, odds ratios, p-values" },
    { value: "predict", label: "Predict new cases accurately", hint: "Machine learning" }] } as Question,
  survival: { id: "survival", text: "What do you want to do?", choices: [
    { value: "compare", label: "Compare survival curves", hint: "Kaplan-Meier, log-rank" },
    { value: "adjust", label: "Adjust for several factors", hint: "Hazard ratios" }] } as Question,
  ts: { id: "ts", text: "What do you want to do?", choices: [
    { value: "explore", label: "Explore trend and seasonality" }, { value: "forecast", label: "Forecast future values" }] } as Question,
  structure: { id: "structure", text: "What are you looking for?", choices: [
    { value: "variables", label: "Fewer summary variables", hint: "Principal components" },
    { value: "latent", label: "Underlying factors behind items", hint: "Questionnaire scales" },
    { value: "cases", label: "Groups of similar cases", hint: "Clusters" }] } as Question,
  agree: { id: "agree", text: "What do you want to check?", choices: [
    { value: "items", label: "Items of a scale hang together", hint: "Internal consistency" },
    { value: "continuous", label: "Raters agree on measurements" },
    { value: "categorical", label: "Raters agree on categories" }] } as Question,
  diag: { id: "diag", text: "What does the test give?", choices: [
    { value: "binary", label: "Positive / negative" }, { value: "score", label: "A score or measurement", hint: "Choose a cut-off" }] } as Question,
  meta: { id: "meta", text: "What does each study report?", choices: [
    { value: "effects", label: "An effect size and its standard error" },
    { value: "binary", label: "Events and totals per arm" },
    { value: "continuous", label: "Means, SDs and sizes per arm" }] } as Question,
  describe: { id: "describe", text: "What kind of summary?", choices: [
    { value: "summary", label: "Statistics and plots per variable" },
    { value: "table1", label: "Baseline table by group (Table 1)" }] } as Question,
};

/** Questions to show for the answers so far, in order. Answering one can add the next. */
export function questions(a: Answers): Question[] {
  const out: Question[] = [];
  const ask = (q: Question) => { out.push(q); return a[q.id] !== undefined; };
  switch (a.goal) {
    case "compare":
      if (!ask(Q.outcome())) break;
      if (!ask(Q.groups)) break;
      if (a.groups !== "one" && !ask(Q.design)) break;
      if (a.outcome === "continuous" && a.groups === "many" && a.design === "independent" && !ask(Q.factors)) break;
      if (a.outcome === "continuous" && !(a.groups === "many" && a.factors === "several")) ask(Q.normal);
      break;
    case "relate": ask(Q.kind); break;
    case "predict":
      if (!ask(Q.outcome())) break;
      if (!ask(Q.clustered)) break;
      if (a.clustered === "no" && a.outcome !== "count" && a.outcome !== "ordinal") ask(Q.purpose);
      break;
    case "describe": ask(Q.describe); break;
    case "agreement": ask(Q.agree); break;
    case "survival": ask(Q.survival); break;
    case "time": ask(Q.ts); break;
    case "structure": ask(Q.structure); break;
    case "diagnostic": ask(Q.diag); break;
    case "meta": ask(Q.meta); break;
  }
  return out;
}

/** Bayesian counterpart of a frequentist analysis, where one exists. */
export const BAYES: Record<string, string> = {
  ttest_one: "bayes_ttest_one", ttest_ind: "bayes_ttest_ind", ttest_paired: "bayes_ttest_paired",
  anova_oneway: "bayes_anova", anova_factorial: "bayes_anova", correlation: "bayes_cor", chisq: "bayes_contingency",
  binomial_test: "bayes_binomial", reg_linear: "bayes_regression",
};

function compare(a: Answers): Recommendation | null {
  const { outcome, groups, design, normal } = a;
  const skewed = normal === "no";
  if (outcome === "continuous") {
    if (groups === "one") return skewed
      ? { module: "ttest_one", options: { test: ["wilcoxon"] }, why: "One sample against a test value; the Wilcoxon signed-rank test does not assume normality.", alternatives: [] }
      : { module: "ttest_one", why: "Compares one sample's mean with a known or hypothesised value.", alternatives: [{ module: "ttest_one", options: { test: ["wilcoxon"] }, why: "Wilcoxon signed-rank if the data are skewed." }] };
    if (groups === "two" && design === "independent") return skewed
      ? { module: "ttest_ind", options: { test: ["mann_whitney"] }, why: "Two independent groups with a skewed outcome: the Mann-Whitney U test compares ranks.", alternatives: [{ module: "ttest_ind", why: "Welch's t-test if the groups are large." }] }
      : { module: "ttest_ind", why: "Two independent groups and a measurement: Welch's t-test compares the means without assuming equal variances.", alternatives: [{ module: "ttest_ind", options: { test: ["mann_whitney"] }, why: "Mann-Whitney U if the data are skewed." }] };
    if (groups === "two") return skewed
      ? { module: "wilcoxon_paired", why: "The same people measured twice with skewed differences: the Wilcoxon signed-rank test.", alternatives: [{ module: "ttest_paired", why: "Paired t-test if the differences are roughly normal." }] }
      : { module: "ttest_paired", why: "The same people measured twice: the paired t-test compares the mean change with zero.", alternatives: [{ module: "wilcoxon_paired", why: "Wilcoxon signed-rank if the differences are skewed." }] };
    if (design === "paired") return skewed
      ? { module: "friedman", why: "Three or more repeated measurements with skewed data: the Friedman test compares ranks.", alternatives: [{ module: "anova_rm", why: "Repeated-measures ANOVA if the data are roughly normal." }] }
      : { module: "anova_rm", why: "Three or more repeated measurements on the same people: repeated-measures ANOVA.", alternatives: [{ module: "friedman", why: "Friedman test if the data are skewed." }, { module: "mixed_linear", why: "Linear mixed model if there are missing time points (long format)." }] };
    if (a.factors === "several") return { module: "anova_factorial", why: "Two or more grouping factors: factorial ANOVA tests each factor and their interaction.", alternatives: [{ module: "reg_linear", why: "Linear regression gives the same model as coefficients." }] };
    return skewed
      ? { module: "anova_oneway", options: { test: ["kruskal"] }, why: "Three or more independent groups with skewed data: the Kruskal-Wallis test, with Dunn's post hoc tests.", alternatives: [{ module: "anova_oneway", why: "Welch ANOVA if the groups are large." }] }
      : { module: "anova_oneway", why: "Three or more independent groups: one-way ANOVA (Welch's version does not assume equal variances), with post hoc tests.", alternatives: [{ module: "anova_oneway", options: { test: ["kruskal"] }, why: "Kruskal-Wallis if the data are skewed." }] };
  }
  if (outcome === "ordinal") {
    if (groups === "one") return { module: "chisq_gof", why: "Compares the distribution over categories with expected proportions.", alternatives: [{ module: "binomial_test", why: "Binomial test for one category's proportion." }] };
    if (groups === "two") return design === "paired"
      ? { module: "wilcoxon_paired", why: "Ordered outcome measured twice on the same people: the Wilcoxon signed-rank test.", alternatives: [] }
      : { module: "ttest_ind", options: { test: ["mann_whitney"] }, why: "Ordered outcome in two independent groups: the Mann-Whitney U test.", alternatives: [{ module: "reg_ordinal", why: "Ordinal regression to adjust for other variables." }] };
    return design === "paired"
      ? { module: "friedman", why: "Ordered outcome on three or more occasions: the Friedman test.", alternatives: [] }
      : { module: "anova_oneway", options: { test: ["kruskal"] }, why: "Ordered outcome in three or more groups: the Kruskal-Wallis test.", alternatives: [{ module: "reg_ordinal", why: "Ordinal regression to adjust for other variables." }] };
  }
  if (outcome === "binary" || outcome === "nominal") {
    if (groups === "one") return outcome === "binary"
      ? { module: "binomial_test", why: "One proportion against a test value: the exact binomial test.", alternatives: [] }
      : { module: "chisq_gof", why: "Category proportions against expected ones: the chi-square goodness-of-fit test.", alternatives: [] };
    if (design === "paired") return groups === "two"
      ? { module: "mcnemar", why: "A yes/no outcome measured twice on the same people: McNemar's test.", alternatives: [] }
      : { module: "cochran_q", why: "A yes/no outcome on three or more occasions: Cochran's Q test.", alternatives: [] };
    return { module: "chisq", why: "Categories across independent groups: the chi-square test of independence (Fisher's exact test for small counts).", alternatives: [{ module: outcome === "binary" ? "reg_logistic" : "reg_multinomial", why: "Regression to adjust for other variables." }] };
  }
  if (outcome === "count") return { module: "reg_count", why: "Counts compared across groups: Poisson or negative binomial regression with the group as a factor.", alternatives: [{ module: "anova_oneway", options: { test: ["kruskal"] }, why: "Kruskal-Wallis as a simple rank-based comparison." }] };
  return null;
}

function predict(a: Answers): Recommendation | null {
  const o = a.outcome;
  if (a.clustered === "yes") return o === "continuous"
    ? { module: "mixed_linear", why: "Grouped observations: a linear mixed model adds a random effect for each cluster.", alternatives: [] }
    : { module: "mixed_glmm", why: "Grouped observations with a yes/no or count outcome: a generalized linear mixed model.", alternatives: [] };
  if (o === "count") return { module: "reg_count", why: "A count outcome: Poisson regression (negative binomial if overdispersed).", alternatives: [] };
  if (o === "ordinal") return { module: "reg_ordinal", why: "Ordered categories: proportional-odds ordinal regression.", alternatives: [{ module: "reg_multinomial", why: "Multinomial regression if the odds are not proportional." }] };
  const ml = [
    { module: "ml_forest", why: "Random forest: strong default, little tuning." },
    { module: "ml_boost", why: "Gradient boosting: often the most accurate." },
    { module: "ml_glmnet", why: "Elastic net: a regularized regression that stays interpretable." },
    { module: "ml_tree", why: "Decision tree: simple rules you can read." },
  ];
  if (a.purpose === "predict") return { ...ml[0], alternatives: ml.slice(1) };
  if (o === "continuous") return { module: "reg_linear", why: "A measured outcome: linear regression gives the effect of each predictor.", alternatives: [ml[0]] };
  if (o === "binary") return { module: "reg_logistic", why: "A yes/no outcome: logistic regression gives odds ratios.", alternatives: [ml[0], { module: "roc", why: "ROC curve to judge one score's accuracy." }] };
  if (o === "nominal") return { module: "reg_multinomial", why: "Unordered categories: multinomial logistic regression.", alternatives: [ml[0], { module: "ml_lda", why: "Discriminant analysis as a classifier." }] };
  return null;
}

const SIMPLE: Partial<Record<Goal, (a: Answers) => Recommendation | null>> = {
  relate: (a) => a.kind === "categorical"
    ? { module: "chisq", why: "Two categorical variables: the chi-square test of independence with Cramér's V.", alternatives: [] }
    : a.kind === "ordinal"
      ? { module: "correlation", options: { method: "spearman" }, why: "Ranks or ordered categories: Spearman's rank correlation.", alternatives: [{ module: "correlation", options: { method: "kendall" }, why: "Kendall's tau for many tied values." }] }
      : a.kind ? { module: "correlation", why: "Two measurements: Pearson's correlation (Spearman if the relation is not linear).", alternatives: [{ module: "reg_linear", why: "Linear regression to predict one from the other." }] } : null,
  describe: (a) => a.describe === "table1"
    ? { module: "clin_table1", why: "Baseline characteristics by group in one publication-ready table.", alternatives: [] }
    : a.describe ? { module: "descriptives", why: "Means, medians, SDs, counts and plots for each variable.", alternatives: [{ module: "clin_table1", why: "Table 1 by group." }] } : null,
  agreement: (a) => ({ items: { module: "reliability_alpha", why: "Cronbach's alpha and item statistics.", alternatives: [{ module: "efa", why: "Factor analysis to check the scale has one dimension." }] },
    continuous: { module: "reliability_icc", why: "Intraclass correlation for raters' measurements.", alternatives: [] },
    categorical: { module: "reliability_kappa", why: "Cohen's kappa for two raters' categories.", alternatives: [] } } as Record<string, Recommendation>)[a.agree ?? ""] ?? null,
  survival: (a) => a.survival === "adjust"
    ? { module: "surv_cox", why: "Cox regression gives hazard ratios adjusted for several factors.", alternatives: [{ module: "surv_km", why: "Kaplan-Meier curves to show the data." }] }
    : a.survival ? { module: "surv_km", why: "Kaplan-Meier curves with a log-rank test between groups.", alternatives: [{ module: "surv_cox", why: "Cox regression to adjust for other factors." }] } : null,
  time: (a) => a.ts === "forecast"
    ? { module: "ts_arima", why: "ARIMA picks a model automatically and forecasts with prediction intervals.", alternatives: [{ module: "ts_ets", why: "Exponential smoothing: often as good for seasonal data." }] }
    : a.ts ? { module: "ts_explore", why: "Plots the series, splits trend and seasonality and tests stationarity.", alternatives: [] } : null,
  structure: (a) => ({ variables: { module: "pca", why: "Principal components summarise many correlated variables in a few.", alternatives: [{ module: "efa", why: "Factor analysis for latent constructs." }] },
    latent: { module: "efa", why: "Exploratory factor analysis finds the factors behind questionnaire items.", alternatives: [{ module: "reliability_alpha", why: "Then check each scale's reliability." }] },
    cases: { module: "cluster_kmeans", why: "k-means groups similar cases; silhouette widths help choose k.", alternatives: [{ module: "cluster_hier", why: "Hierarchical clustering with a dendrogram." }] } } as Record<string, Recommendation>)[a.structure ?? ""] ?? null,
  diagnostic: (a) => a.diag === "score"
    ? { module: "roc", why: "ROC curve, AUC and the best cut-off for a score.", alternatives: [{ module: "diag_2x2", why: "Sensitivity and specificity at a fixed cut-off." }] }
    : a.diag ? { module: "diag_2x2", why: "Sensitivity, specificity, predictive values and likelihood ratios against a reference standard.", alternatives: [] } : null,
  meta: (a) => ({ effects: { module: "meta_generic", why: "Random-effects meta-analysis of ready-made effect sizes.", alternatives: [] },
    binary: { module: "meta_binary", why: "Odds or risk ratios pooled from 2 × 2 counts per study.", alternatives: [] },
    continuous: { module: "meta_continuous", why: "Mean differences (or SMDs) pooled from group means and SDs.", alternatives: [] } } as Record<string, Recommendation>)[a.meta ?? ""] ?? null,
};

/** The recommended analysis once every applicable question is answered; null before that. */
export function recommend(a: Answers): Recommendation | null {
  if (!a.goal) return null;
  if (questions(a).some((q) => a[q.id] === undefined)) return null;
  const r = a.goal === "compare" ? compare(a) : a.goal === "predict" ? predict(a) : SIMPLE[a.goal]?.(a) ?? null;
  if (!r) return null;
  const bayes = BAYES[r.module];
  const parametric = !r.options || !Object.values(r.options).flat().some((v) => ["mann_whitney", "kruskal", "wilcoxon", "spearman", "kendall"].includes(String(v)));
  if (!bayes || !parametric) return r;
  const bp: Pick = { module: bayes, why: "Bayesian version: a Bayes factor weighs the evidence for and against an effect." };
  if (a.approach === "bayesian") return { ...bp, alternatives: [{ module: r.module, options: r.options, why: "Frequentist version (p-values)." }, ...r.alternatives] };
  return { ...r, alternatives: [...r.alternatives, bp] };
}

/** True when the recommendation has a Bayesian counterpart (so the dialog offers the switch). */
export function hasBayesian(a: Answers): boolean {
  const r = recommend({ ...a, approach: "frequentist" });
  return !!r && r.alternatives.some((p) => p.module.startsWith("bayes_"));
}

/** Outcome type from a variable: measure plus the number of distinct values. */
export function outcomeOf(v: VariableMeta, distinct: number): Outcome {
  if (v.measure === "continuous") return "continuous";
  if (v.measure === "ordinal") return distinct === 2 ? "binary" : "ordinal";
  return distinct <= 2 ? "binary" : "nominal";
}

/** Put the chosen outcome and group variables into the first roles that accept them. */
export function assignRoles(spec: ModuleSpec, data: DataInfo | null, outcome?: string, group?: string): Options {
  const out: Options = {};
  const used = new Set<string>();
  for (const name of [outcome, group]) {
    const v = name && data?.variables.find((x) => x.name === name);
    if (!v) continue;
    const role = spec.roles.find((r) => !used.has(r.id) && (r.measure.length === 0 || r.measure.includes(v.measure)));
    if (!role) continue;
    used.add(role.id);
    out[role.id] = [v.name];
  }
  return out;
}
