import { expect, test } from '@playwright/test';

test.describe('Shell layout', () => {
  test('renders home page with expected text', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Canopy is ready.' })).toBeVisible();
    await expect(page.getByText('Runtime scaffolding complete. Week 1 begins.')).toBeVisible();
  });

  test('sidebar is present with Canopy wordmark', async ({ page }) => {
    await page.goto('/');
    const sidebar = page.getByRole('complementary', {
      name: 'Primary navigation',
    });
    await expect(sidebar).toBeVisible();
    await expect(sidebar.getByText('Canopy')).toBeVisible();
  });

  test('theme toggle button is present and accessible', async ({ page }) => {
    await page.goto('/');
    const toggle = page.getByRole('button', {
      name: /Switch to (light|dark) mode/,
    });
    await expect(toggle).toBeVisible();
  });
});
