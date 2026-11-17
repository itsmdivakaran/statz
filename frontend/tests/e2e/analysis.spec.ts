import { expect, test, type Page } from "@playwright/test";

async function menu(page: Page, top: string, item: string) {
  await page.locator("header").getByRole("button", { name: top, exact: true }).click();
  await page.getByRole("menuitem", { name: item, exact: true }).click();
}

async function assign(page: Page, variable: string, role: string) {
  await page.locator(`[data-var="${variable}"]`).click();
  await page.getByRole("button", { name: `Add to ${role}` }).click();
}

test("independent t-test: dialog → R → APA table, plot, code, interpretation", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Motor Trend cars (1974)");
  await expect(page.getByTestId("data-grid")).toContainText("Mazda RX4");
  await menu(page, "Tests", "Independent Samples T-Test");
  await assign(page, "mpg", "Dependent variables");
  await assign(page, "am", "Grouping variable");

  const result = page.getByTestId("result-ttest_ind");
  await expect(result.locator("table").nth(1)).toContainText("Welch");
  await expect(result).toContainText("−3.77");
  await expect(result).toContainText("18.33");
  await expect(result).toContainText("[−11.28, −3.21]");
  await expect(result.locator("iframe, img").first()).toBeVisible();

  // Live update: ticking Student adds a row without pressing anything.
  await page.getByLabel("Student").check();
  await expect(result).toContainText("−4.11");

  await page.getByRole("tab", { name: "R Code" }).click();
  await expect(page.getByLabel("R code")).toHaveValue(/t\.test\(mpg ~ am, data = d, var\.equal = FALSE/);

  await page.getByRole("tab", { name: "Interpretation" }).click();
  await expect(result).toContainText("t(18.33) = −3.77, p = .001");
});

test("chi-square on example data", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Infertility after abortion");
  await menu(page, "Tests", "Chi-Square Test of Association");
  await assign(page, "spontaneous", "Rows");
  await assign(page, "case", "Columns");
  const result = page.getByTestId("result-chisq");
  await expect(result).toContainText("Pearson χ²");
  await expect(result).toContainText("Cramér's V");
});

test("invalid assignment shows the reason from R", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Motor Trend cars (1974)");
  await menu(page, "Tests", "Independent Samples T-Test");
  await assign(page, "mpg", "Dependent variables");
  // cyl is ordinal with 3 levels: allowed by measure, rejected by R for level count.
  await assign(page, "cyl", "Grouping variable");
  await expect(page.getByRole("alert")).toContainText("3 levels");
});

test("Cox regression: hazard ratios, forest plot and proportional-hazards check", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Lung cancer survival");
  await menu(page, "Survival", "Cox Regression");
  await assign(page, "time", "Time");
  await assign(page, "status", "Event status (2 values)");
  await assign(page, "age", "Covariates (continuous)");
  await assign(page, "sex", "Factors (categorical)");
  const result = page.getByTestId("result-surv_cox");
  await expect(result).toContainText("Hazard ratio");
  await expect(result).toContainText("sexFemale");
  await expect(result).toContainText("0.599");
  await expect(result.locator("iframe, img").first()).toBeVisible();
  await page.getByRole("tab", { name: "Assumptions" }).click();
  await expect(result).toContainText("Proportional hazards");
  await page.getByRole("tab", { name: "R Code" }).click();
  await expect(page.getByLabel("R code")).toHaveValue(/coxph\(Surv\(time, event\) ~ age \+ sex/);
});

test("linear mixed model: random slope chosen in the dialog", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Sleep deprivation study");
  await menu(page, "Regression", "Linear Mixed Model");
  await assign(page, "reaction", "Dependent variable");
  await assign(page, "days", "Covariates (continuous)");
  await assign(page, "subject", "Grouping variable (random intercept)");
  const result = page.getByTestId("result-mixed_linear");
  await expect(result).toContainText("Random Effects");
  await page.getByRole("group", { name: "Random slopes for" }).getByRole("button", { name: "days" }).click();
  await expect(result).toContainText("5.922");
  await page.getByRole("tab", { name: "R Code" }).click();
  await expect(page.getByLabel("R code")).toHaveValue(/\(1 \+ days \| subject\)/);
});

test("compute, recode and filter change the data and can be undone", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Motor Trend cars (1974)");
  await expect(page.getByText("mtcars.csv · 32 × 12")).toBeVisible();

  await menu(page, "Data", "Compute variable…");
  await page.getByLabel("New variable name").fill("kpl");
  await page.getByLabel("Expression").fill("mpg *");
  await page.getByRole("button", { name: "Compute", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("not a complete R expression");
  await page.getByLabel("Expression").fill("mpg * 0.425");
  await page.getByRole("button", { name: "Compute", exact: true }).click();
  await expect(page.getByText("mtcars.csv · 32 × 13")).toBeVisible();

  await menu(page, "Data", "Recode variable…");
  await page.getByLabel("Variable to recode").selectOption("cyl");
  await page.getByLabel("New value for 4").fill("small");
  await page.getByLabel("New value for 6").fill("large");
  await page.getByLabel("New value for 8").fill("large");
  await page.getByRole("button", { name: "Recode", exact: true }).click();
  await expect(page.getByText("mtcars.csv · 32 × 14")).toBeVisible();

  await menu(page, "Data", "Filter rows…");
  await page.getByLabel("Expression").fill('cyl_r == "small"');
  await page.getByRole("button", { name: "Filter", exact: true }).click();
  await expect(page.getByText("mtcars.csv · 11 × 14")).toBeVisible();

  await page.keyboard.press("Control+z");
  await expect(page.getByText("mtcars.csv · 32 × 14")).toBeVisible();
  await page.keyboard.press("Control+z");
  await expect(page.getByText("mtcars.csv · 32 × 13")).toBeVisible();
  await page.keyboard.press("Control+Shift+z");
  await expect(page.getByText("mtcars.csv · 32 × 14")).toBeVisible();
});
