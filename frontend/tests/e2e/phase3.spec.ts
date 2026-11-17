import { expect, test, type Page } from "@playwright/test";

async function menu(page: Page, top: string, item: string) {
  await page.locator("header").getByRole("button", { name: top, exact: true }).click();
  await page.getByRole("menuitem", { name: item, exact: true }).click();
}

test("landing page: worked example opens data, analysis and result", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: /Welcome to Stat/ })).toBeVisible();
  await page.getByLabel("Filter datasets").fill("vaccine");
  await expect(page.getByRole("button", { name: "BCG vaccine trials" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Iris flowers" })).toHaveCount(0);
  await page.getByRole("button", { name: /Principal Component Analysis/ }).click();
  const result = page.getByTestId("result-pca");
  await expect(result).toContainText("Variance Explained");
  await expect(result).toContainText("62.0");
  await expect(page.getByTestId("data-grid")).toContainText("Alabama");
});

test("panes can be minimized, restored and maximized", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Iris flowers");
  await menu(page, "Multivariate", "K-Means Clustering");
  await page.locator('[data-var="sepal_length"]').click();
  await page.getByRole("button", { name: "Add to Variables" }).click();
  await page.locator('[data-var="petal_length"]').click();
  await page.getByRole("button", { name: "Add to Variables" }).click();
  await expect(page.getByTestId("result-cluster_kmeans")).toContainText("Cluster Sizes");

  await page.getByRole("button", { name: "Minimize Data pane" }).click();
  await expect(page.locator('[data-pane="data"]')).toHaveAttribute("data-state", "min");
  await page.getByRole("button", { name: "Show Data pane" }).click();
  await expect(page.locator('[data-pane="data"]')).toHaveAttribute("data-state", "normal");

  await page.getByRole("button", { name: "Maximize Output pane" }).click();
  await expect(page.locator('[data-pane="results"]')).toHaveAttribute("data-state", "max");
  await expect(page.locator('[data-pane="data"]')).toBeHidden();
  await page.getByRole("button", { name: "Restore Output pane" }).click();
  await expect(page.locator('[data-pane="data"]')).toBeVisible();
});

test("output pane offers Word, PDF and HTML export", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /ROC Curve Analysis/ }).click();
  await expect(page.getByTestId("result-roc")).toContainText("0.731");
  await page.getByRole("button", { name: "Export", exact: true }).click();
  for (const name of [/Word document/, /PDF/, /Web page/]) await expect(page.getByRole("menuitem", { name })).toBeVisible();
});

test("time series and machine learning menus run their analyses", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /ARIMA Forecast/ }).click();
  const ts = page.getByTestId("result-ts_arima");
  await expect(ts).toContainText("ARIMA(0,1,1)(0,1,1)[12]");
  await expect(ts.locator("iframe, img").first()).toBeVisible();
  await menu(page, "Data", "Diabetes in Pima women");
  await menu(page, "Machine Learning", "Random Forest");
  await page.locator('[data-var="diabetes"]').click();
  await page.getByRole("button", { name: "Add to Outcome (categorical or numeric)" }).click();
  await page.locator('[data-var="glucose"]').click();
  await page.getByRole("button", { name: "Add to Numeric predictors" }).click();
  await expect(page.getByTestId("result-ml_forest")).toContainText("Test-Set Performance");
});
