import { expect, test, type Page } from "@playwright/test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

async function menu(page: Page, top: string, item: string) {
  await page.locator("header").getByRole("button", { name: top, exact: true }).click();
  await page.getByRole("menuitem", { name: item, exact: true }).click();
}

test("guide recommends a test and opens it, Bayesian on request", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Which test should I use?" }).click();
  const guide = page.getByRole("dialog", { name: "Analysis guide" });
  await guide.getByRole("button", { name: /Compare groups or conditions/ }).click();
  await guide.getByRole("button", { name: /A measurement/ }).click();
  await guide.getByRole("button", { name: /^Two$/ }).click();
  await guide.getByRole("button", { name: /Yes, same people/ }).click();
  await guide.getByRole("button", { name: /No, skewed/ }).click();
  await expect(guide.getByTestId("guide-pick")).toHaveText("Wilcoxon Signed-Rank Test");
  await guide.getByRole("button", { name: /Yes, or not sure/ }).click();
  await expect(guide.getByTestId("guide-pick")).toHaveText("Paired Samples T-Test");
  await guide.getByRole("button", { name: "Bayesian", exact: true }).click();
  await expect(guide.getByTestId("guide-pick")).toHaveText("Bayesian Paired Samples T-Test");
  await guide.getByRole("button", { name: /Try it on example data/ }).click();
  const result = page.getByTestId("result-bayes_ttest_paired");
  await expect(result).toContainText("17.3");
  await expect(result).toContainText("Strong evidence for H");
});

test("guide fills the variables in from the data", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Motor Trend cars (1974)");
  await page.getByRole("button", { name: "Analysis guide" }).click();
  const guide = page.getByRole("dialog", { name: "Analysis guide" });
  await guide.getByRole("button", { name: /Compare groups or conditions/ }).click();
  await guide.getByLabel("Outcome variable").selectOption("mpg");
  await guide.getByLabel("Group variable").selectOption("am");
  await guide.getByRole("button", { name: /Yes, or not sure/ }).click();
  await expect(guide.getByTestId("guide-pick")).toHaveText("Independent Samples T-Test");
  await guide.getByRole("button", { name: /Open this analysis/ }).click();
  await expect(page.getByTestId("result-ttest_ind")).toContainText("Welch");
});

test("Bayesian menu runs a Bayesian ANOVA", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Tooth growth");
  await menu(page, "Bayesian", "Bayesian ANOVA");
  await page.locator('[data-var="len"]').click();
  await page.getByRole("button", { name: "Add to Dependent variable" }).click();
  await page.locator('[data-var="supp"]').click();
  await page.getByRole("button", { name: "Add to Fixed factors" }).click();
  await page.locator('[data-var="dose"]').click();
  await page.getByRole("button", { name: "Add to Fixed factors" }).click();
  const result = page.getByTestId("result-bayes_anova");
  await expect(result).toContainText("Model Comparison", { timeout: 30_000 });
  await expect(result).toContainText("supp + dose + supp:dose");
  await expect(result).toContainText("Analysis of Effects");
});

test("plugins: create the starter plugin, install it and run it", async ({ page }) => {
  const dir = mkdtempSync(path.join(tmpdir(), "statnext-plugin-"));
  page.on("dialog", (d) => void d.accept(dir));
  await page.goto("/");
  await menu(page, "Data", "Iris flowers");
  await menu(page, "Plugins", "Manage plugins…");
  const mgr = page.getByRole("dialog", { name: "Plugins" });
  await expect(mgr).toContainText("No plugins yet");
  await mgr.getByRole("button", { name: /Create a starter plugin/ }).click();
  await expect(mgr).toContainText("Starter plugin written to");
  await expect(mgr).toContainText("Plugins run R code on this computer");
  await mgr.getByRole("button", { name: "Install plugin" }).click();
  await expect(mgr).toContainText('Installed "Coefficient of Variation"');
  await expect(mgr).toContainText("Installed (1)");
  await page.keyboard.press("Escape");
  await menu(page, "Plugins", "Coefficient of Variation");
  await page.locator('[data-var="sepal_length"]').click();
  await page.getByRole("button", { name: "Add to Variables" }).click();
  await expect(page.getByTestId("result-coef_variation")).toContainText("CV (%)");
  await menu(page, "Plugins", "Manage plugins…");
  await mgr.getByRole("button", { name: "Remove Coefficient of Variation" }).click();
  await mgr.getByRole("button", { name: "Confirm remove" }).click();
  await expect(mgr).toContainText("No plugins yet");
});
