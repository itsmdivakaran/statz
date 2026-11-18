import { expect, test, type Page } from "@playwright/test";

async function menu(page: Page, top: string, item: string) {
  await page.locator("header").getByRole("button", { name: top, exact: true }).click();
  await page.getByRole("menuitem", { name: item, exact: true }).click();
}

/** Drag with real pointer events, as a user would. */
async function drag(page: Page, from: string, to: string) {
  const a = await page.locator(from).boundingBox();
  const b = await page.locator(to).boundingBox();
  if (!a || !b) throw new Error("drag target not found");
  await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2);
  await page.mouse.down();
  await page.mouse.move(a.x + a.width / 2 + 12, a.y + a.height / 2 + 6, { steps: 3 });
  await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2, { steps: 8 });
  await page.mouse.up();
}

test("variables drag into role boxes, between boxes and back", async ({ page }) => {
  await page.goto("/");
  await menu(page, "Data", "Motor Trend cars (1974)");
  await menu(page, "Tests", "Independent Samples T-Test");
  await drag(page, '[data-var="mpg"]', '[data-drop="dv"]');
  await expect(page.locator('[data-drop="dv"]')).toContainText("mpg");
  await drag(page, '[data-var="am"]', '[data-drop="group"]');
  await expect(page.getByTestId("result-ttest_ind")).toContainText("Welch");
  // A continuous variable is refused by the grouping box (nominal/ordinal only)…
  await drag(page, '[data-var="hp"]', '[data-drop="group"]');
  await expect(page.locator('[data-drop="group"]')).not.toContainText("hp");
  // …and an assigned variable can be dragged back to the list.
  await drag(page, '[data-drop="dv"] li:has-text("mpg")', '[data-drop="__free"]');
  await expect(page.locator('[data-drop="dv"]')).not.toContainText("mpg");
  // Double-click adds to the first box that accepts it.
  await page.locator('[data-var="wt"]').dblclick();
  await expect(page.locator('[data-drop="dv"]')).toContainText("wt");
});

test("AI assistant: off by default, key setup, explain a result", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => localStorage.removeItem("statnext.ai"));
  await page.reload();
  await page.getByRole("button", { name: "AI assistant" }).click();
  await expect(page.getByRole("complementary", { name: "AI assistant" })).toContainText("The AI assistant is off.");
  await page.getByRole("button", { name: "Open AI settings" }).click();
  await page.getByLabel("Turn on the AI assistant").check();
  await page.getByLabel("API key").fill("sk-test");
  await page.getByRole("button", { name: "Save key" }).click();
  await expect(page.getByRole("dialog", { name: "Settings" })).toContainText("Key saved");
  await page.getByRole("button", { name: "Done" }).click();

  await page.locator("main button", { hasText: "Independent Samples T-Test" }).first().click();
  const result = page.getByTestId("result-ttest_ind");
  await expect(result).toContainText("Welch");
  await result.getByRole("button", { name: "Explain" }).click();
  const panel = page.getByRole("complementary", { name: "AI assistant" });
  await expect(panel).toContainText("Result 1: Independent Samples T-Test");
  await panel.getByRole("button", { name: /Result 1/ }).click();
  await expect(panel.locator("pre")).toContainText("| Variable | Test |");
  await panel.getByRole("button", { name: "Send" }).click();
  await expect(panel).toContainText("mock reply");
});
