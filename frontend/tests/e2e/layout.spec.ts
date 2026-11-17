import { expect, test, type Page } from "@playwright/test";

async function menu(page: Page, top: string, item: string) {
  await page.locator("header").getByRole("button", { name: top, exact: true }).click();
  await page.getByRole("menuitem", { name: item, exact: true }).click();
}

test("panes resize by dragging the divider, and the status bar shows the dataset", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => localStorage.clear());
  await menu(page, "Data", "Iris flowers");
  await expect(page.getByLabel("Status")).toContainText("150 rows, 5 variables");
  const data = page.locator('[data-pane="data"]');
  const results = page.locator('[data-pane="results"]');
  const before = (await data.boundingBox())!.width;
  const resultsBefore = (await results.boundingBox())!.width;
  const bar = (await page.getByRole("separator", { name: "Resize Data pane" }).boundingBox())!;
  await page.mouse.move(bar.x + bar.width / 2, bar.y + 200);
  await page.mouse.down();
  await page.mouse.move(bar.x + 60, bar.y + 200, { steps: 5 });
  await page.mouse.up();
  const after = (await data.boundingBox())!.width;
  expect(after - before).toBeGreaterThan(50);
  // The neighbour gives up the width; the Output pane keeps its size.
  expect(Math.abs((await results.boundingBox())!.width - resultsBefore)).toBeLessThan(2);
});

test("opening another dataset clears results computed on the old one", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /Independent Samples T-Test/ }).first().click();
  const result = page.getByTestId("result-ttest_ind");
  await expect(result).toContainText("Welch");
  await menu(page, "Data", "Iris flowers");
  await expect(result).toContainText("Assign variables to run this analysis.");
  await expect(result).not.toContainText("Welch");
});

test("toolbar undo reverts an option change", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /Independent Samples T-Test/ }).first().click();
  await expect(page.getByTestId("result-ttest_ind")).toContainText("Welch");
  const undo = page.getByRole("button", { name: "Undo", exact: true });
  await expect(undo).toBeDisabled();
  await page.getByLabel("Student").check();
  await expect(page.getByTestId("result-ttest_ind")).toContainText("Student");
  await undo.click();
  await expect(page.getByLabel("Student")).not.toBeChecked();
});
