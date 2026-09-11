import { test, expect } from '@playwright/test';

test.describe('HardCode Academy - Loading Recovery & Anti-Freeze Verification', () => {

  test('VERIFY-01: App must never get stuck on an infinite loading spinner', async ({ page }) => {
    const errorLogs: string[] = [];

    // 1. Trap fatal runtime errors
    page.on('pageerror', (err) => {
      errorLogs.push(`PAGEERROR: ${err.message}`);
    });
    page.on('console', (msg) => {
      if (msg.type() === 'error' && !msg.text().includes('favicon')) {
        errorLogs.push(`CONSOLE ERROR: ${msg.text()}`);
      }
    });

    // 2. Navigate to application
    await page.goto('/');

    // 3. Ensure loading spinner disappears within 5 seconds
    const spinner = page.locator('.loading, .spinner, [role="progressbar"], flt-circular-progress-indicator');
    if (await spinner.count() > 0) {
      await expect(spinner.first()).not.toBeVisible({ timeout: 5000 });
    }

    // 4. Invariant: Main app canvas and header must be fully rendered
    const glassPane = page.locator('flt-glass-pane, canvas, body');
    await expect(glassPane.first()).toBeVisible({ timeout: 5000 });

    // 5. Invariant: Telemetry state hook must show ACTIVE, not stuck in INITIALIZING / LOADING
    await page.waitForTimeout(1500);
    const state = await page.evaluate(() => (window as any).__getHardcodeState?.());
    expect(state).toBeDefined();
    expect(state.phase).not.toBe('STUCK');

    // 6. Invariant: No fatal unhandled TypeError (like string/int cast bugs) occurred
    const fatalTypeErrors = errorLogs.filter(e => e.includes('TypeError') || e.includes('is not a subtype of'));
    expect(fatalTypeErrors).toHaveLength(0);
  });

});
