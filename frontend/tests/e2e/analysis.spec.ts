import { expect, test, type Page } from "@playwright/test";

async function menu(page: Page, top: string, item: string) {
  await page.locator("header").getByRole("button", { name: top, exact: true }).click();
  await page.getByRole("menuitem", { name: item }).click();
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
