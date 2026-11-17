# Writes the Phase 3 example datasets (datasets/*.csv + *.meta.json). Run from the repo root.
# Needs: psych, pROC, metafor, metadat, MASS. The two CDISC-style datasets are simulated with a fixed seed.
w <- function(d, name, title, desc, vars = list()) {
  write.csv(d, file.path("datasets", paste0(name, ".csv")), row.names = FALSE)
  jsonlite::write_json(list(title = title, description = desc, variables = vars),
                       file.path("datasets", paste0(name, ".meta.json")), auto_unbox = TRUE, pretty = TRUE)
}
vl <- function(...) { x <- list(...); lapply(seq_along(x), function(i) list(value = as.numeric(names(x)[i]), label = x[[i]])) }
lab <- function(...) lapply(list(...), function(l) if (is.list(l)) l else list(label = l))

u <- data.frame(state = rownames(USArrests), murder = USArrests$Murder, assault = USArrests$Assault, urban_pop = USArrests$UrbanPop, rape = USArrests$Rape)
w(u, "usarrests", "US arrests by state (1973)", "Violent crime arrests per 100,000 residents in the 50 US states. Source: R datasets::USArrests (McNeil, 1977).",
  lab(state = "State", murder = "Murder arrests per 100,000", assault = "Assault arrests per 100,000", urban_pop = "Urban population (%)", rape = "Rape arrests per 100,000"))

i <- iris; names(i) <- c("sepal_length", "sepal_width", "petal_length", "petal_width", "species"); i$species <- as.character(i$species)
w(i, "iris", "Iris flowers", "Sepal and petal measurements (cm) of 150 iris flowers from three species. Source: R datasets::iris (Fisher, 1936; Anderson, 1935).",
  lab(sepal_length = "Sepal length (cm)", sepal_width = "Sepal width (cm)", petal_length = "Petal length (cm)", petal_width = "Petal width (cm)", species = "Species"))

b <- psych::bfi[, 1:25]; b$gender <- psych::bfi$gender; b$age <- psych::bfi$age
items <- stats::setNames(lapply(names(b)[1:25], function(n) list(label = paste("Personality item", n), measure = "ordinal")), names(b)[1:25])
w(b, "bfi", "Big Five personality items", "25 personality self-report items (6-point scale) from 2800 people; five items each for Agreeableness, Conscientiousness, Extraversion, Neuroticism and Openness. Source: psych::bfi (International Personality Item Pool).",
  c(items, lab(gender = list(label = "Gender", measure = "nominal", value_labels = vl("1" = "Male", "2" = "Female")), age = "Age (years)")))

data(aSAH, package = "pROC")
a <- data.frame(outcome = as.character(aSAH$outcome), s100b = aSAH$s100b, ndka = aSAH$ndka, wfns = as.integer(as.character(aSAH$wfns)),
                s100b_high = as.integer(aSAH$s100b >= 0.2), age = aSAH$age, gender = as.character(aSAH$gender))
w(a, "asah", "Subarachnoid haemorrhage biomarkers", "Clinical outcome and biomarkers for 113 patients with aneurysmal subarachnoid haemorrhage. s100b_high marks S100B of 0.20 µg/l or more. Source: pROC::aSAH (Turck et al., 2010).",
  lab(outcome = "Outcome at 6 months", s100b = "S100B (µg/l)", ndka = "NDKA (µg/l)", wfns = list(label = "WFNS score", measure = "ordinal"),
      s100b_high = list(label = "S100B ≥ 0.20 µg/l", measure = "nominal", value_labels = vl("0" = "Negative", "1" = "Positive")), age = "Age (years)", gender = "Gender"))

g <- metadat::dat.bcg
es <- metafor::escalc(measure = "RR", ai = tpos, bi = tneg, ci = cpos, di = cneg, data = g)
g <- data.frame(study = paste0(g$author, ", ", g$year), year = g$year, events_vaccine = g$tpos, n_vaccine = g$tpos + g$tneg, events_control = g$cpos,
                n_control = g$cpos + g$cneg, latitude = g$ablat, allocation = g$alloc, log_rr = round(as.numeric(es$yi), 4), se = round(sqrt(es$vi), 4))
w(g, "bcg", "BCG vaccine trials", "13 trials of the BCG vaccine against tuberculosis: cases and group sizes, with the log risk ratio and its standard error. Source: metadat::dat.bcg (Colditz et al., 1994).",
  lab(study = "Study", year = "Publication year", events_vaccine = "TB cases, vaccinated", n_vaccine = "Vaccinated (n)", events_control = "TB cases, control", n_control = "Control (n)",
      latitude = "Absolute latitude", allocation = "Allocation method", log_rr = "Log risk ratio", se = "Standard error"))

n <- metadat::dat.normand1999
n <- data.frame(study = as.character(n$source), n_stroke_unit = n$n1i, mean_stroke_unit = n$m1i, sd_stroke_unit = n$sd1i, n_usual = n$n2i, mean_usual = n$m2i, sd_usual = n$sd2i)
w(n, "stroke_los", "Stroke unit length of stay", "Length of hospital stay (days) in 9 trials comparing specialist stroke units with usual care. Source: metadat::dat.normand1999 (Normand, 1999).",
  lab(study = "Study", n_stroke_unit = "Stroke unit (n)", mean_stroke_unit = "Stroke unit mean stay", sd_stroke_unit = "Stroke unit SD", n_usual = "Usual care (n)", mean_usual = "Usual care mean stay", sd_usual = "Usual care SD"))

bw <- MASS::birthwt
bw <- data.frame(low = bw$low, age = bw$age, mother_weight = bw$lwt, race = bw$race, smoke = bw$smoke, preterm = bw$ptl, hypertension = bw$ht, uterine_irritability = bw$ui, visits = bw$ftv, birth_weight = bw$bwt)
yn <- vl("0" = "No", "1" = "Yes")
w(bw, "birthwt", "Risk factors for low birth weight", "189 births at Baystate Medical Center, 1986. Source: MASS::birthwt (Hosmer & Lemeshow, 1989).",
  lab(low = list(label = "Birth weight below 2.5 kg", measure = "nominal", value_labels = yn), age = "Mother's age (years)", mother_weight = "Mother's weight (lb)",
      race = list(label = "Mother's race", measure = "nominal", value_labels = vl("1" = "White", "2" = "Black", "3" = "Other")), smoke = list(label = "Smoked during pregnancy", measure = "nominal", value_labels = yn),
      preterm = "Previous premature labours", hypertension = list(label = "History of hypertension", measure = "nominal", value_labels = yn),
      uterine_irritability = list(label = "Uterine irritability", measure = "nominal", value_labels = yn), visits = "Physician visits, first trimester", birth_weight = "Birth weight (g)"))

pm <- rbind(MASS::Pima.tr, MASS::Pima.te)
pm <- data.frame(diabetes = as.character(pm$type), pregnancies = pm$npreg, glucose = pm$glu, blood_pressure = pm$bp, skin_fold = pm$skin, bmi = pm$bmi, pedigree = pm$ped, age = pm$age)
w(pm, "pima", "Diabetes in Pima women", "Diabetes status and clinical measurements for 532 women of Pima heritage aged 21 or older. Source: MASS::Pima.tr and Pima.te (Smith et al., 1988).",
  lab(diabetes = "Diabetic (WHO criteria)", pregnancies = "Number of pregnancies", glucose = "Plasma glucose (mg/dl)", blood_pressure = "Diastolic blood pressure (mm Hg)",
      skin_fold = "Triceps skin fold (mm)", bmi = "Body mass index (kg/m²)", pedigree = "Diabetes pedigree function", age = "Age (years)"))

# Simulated CDISC ADaM-style data: subject-level (ADSL) and adverse events (ADAE).
set.seed(20261117)
N <- 254
arm <- sample(rep(c("Placebo", "Drug 54 mg", "Drug 81 mg"), length.out = N))
adsl <- data.frame(USUBJID = sprintf("SN-01-%04d", seq_len(N)), TRT01P = arm, AGE = round(pmin(89, pmax(51, rnorm(N, 75, 8)))),
                   SEX = sample(c("F", "M"), N, TRUE, c(0.56, 0.44)), RACE = sample(c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN"), N, TRUE, c(0.86, 0.11, 0.03)),
                   BMIBL = round(rnorm(N, 25, 4), 1), MMSETOT = pmin(26, pmax(10, round(rnorm(N, 18, 4)))), stringsAsFactors = FALSE)
adsl$DCSREAS <- ifelse(runif(N) < c(Placebo = 0.25, "Drug 54 mg" = 0.38, "Drug 81 mg" = 0.48)[arm], sample(c("Adverse Event", "Withdrew Consent", "Lack of Efficacy"), N, TRUE, c(0.6, 0.25, 0.15)), "Completed")
adsl$BMIBL[sample(N, 3)] <- NA
w(adsl, "adsl_sim", "Clinical trial subjects (simulated ADSL)", "Simulated subject-level analysis dataset in CDISC ADaM layout: 254 subjects in three treatment arms. Not real patient data.",
  lab(USUBJID = "Unique subject identifier", TRT01P = "Planned treatment", AGE = "Age (years)", SEX = "Sex", RACE = "Race", BMIBL = "Baseline BMI (kg/m²)", MMSETOT = "Baseline MMSE total", DCSREAS = "Reason for discontinuation"))
terms <- data.frame(AEDECOD = c("Application site pruritus", "Application site erythema", "Dizziness", "Headache", "Nausea", "Diarrhoea", "Pruritus", "Rash", "Fatigue", "Nasopharyngitis"),
                    AEBODSYS = c(rep("General disorders and administration site conditions", 2), rep("Nervous system disorders", 2), rep("Gastrointestinal disorders", 2),
                                 rep("Skin and subcutaneous tissue disorders", 2), "General disorders and administration site conditions", "Infections and infestations"),
                    p0 = c(0.07, 0.04, 0.03, 0.05, 0.04, 0.10, 0.09, 0.06, 0.02, 0.07), mult = c(3.4, 4, 3, 1.3, 1.6, 0.6, 2.6, 2.2, 3, 1))
adae <- do.call(rbind, lapply(seq_len(N), function(s) {
  dose <- c(Placebo = 0, "Drug 54 mg" = 0.7, "Drug 81 mg" = 1)[arm[s]]
  hit <- runif(nrow(terms)) < terms$p0 * (1 + (terms$mult - 1) * dose)
  if (!any(hit)) return(NULL)
  k <- rep(which(hit), times = sample(1:2, sum(hit), TRUE, c(0.8, 0.2)))
  data.frame(USUBJID = adsl$USUBJID[s], TRT01P = arm[s], AEBODSYS = terms$AEBODSYS[k], AEDECOD = terms$AEDECOD[k],
             AESEV = sample(c("MILD", "MODERATE", "SEVERE"), length(k), TRUE, c(0.62, 0.32, 0.06)), stringsAsFactors = FALSE)
}))
w(adae, "adae_sim", "Adverse events (simulated ADAE)", "Simulated adverse-event records in CDISC ADaM layout for the adsl_sim trial; one row per event. Arm sizes: Placebo 85, Drug 54 mg 85, Drug 81 mg 84. Not real patient data.",
  lab(USUBJID = "Unique subject identifier", TRT01P = "Planned treatment", AEBODSYS = "System organ class", AEDECOD = "Preferred term", AESEV = list(label = "Severity", measure = "ordinal")))
cat(table(arm), "| AE rows", nrow(adae), "\n")
