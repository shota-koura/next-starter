import { test, expect } from '@playwright/test';

test('Home loads', async ({ page }) => {
  const res = await page.goto('/');
  expect(res?.ok()).toBeTruthy();
});
