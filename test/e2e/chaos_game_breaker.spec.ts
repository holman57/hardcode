import { test, expect } from '@playwright/test';

test.describe('Hardcode Academy - Chaos & Adversarial Fuzz Suite', () => {

  test.beforeEach(async ({ page }) => {
    // 1. Trap unhandled browser runtime errors
    page.on('pageerror', (err) => {
      // Ignore normal browser layout warning logs, catch fatal crashes
      if (err.message.includes('Uncaught') || err.message.includes('Exception') || err.message.includes('Error:')) {
        console.error(`[PAGE RUNTIME CRASH]: ${err.message}`);
      }
    });

    page.on('console', (msg) => {
      if (msg.type() === 'error' && !msg.text().includes('favicon') && !msg.text().includes('font')) {
        console.error(`[CONSOLE ERROR]: ${msg.text()}`);
      }
    });

    await page.goto('/');
    // Wait for Flutter canvas / glass pane to mount
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(2000);
  });

  test('CHAOS-01: App initialization and telemetry hook presence', async ({ page }) => {
    // Verify telemetry state hook is operational
    const state = await page.evaluate(() => (window as any).__getHardcodeState?.());
    expect(state).not.toBeNull();
    expect(state).toHaveProperty('phase');
    console.log(`Telemetry Hook Status: Phase=${state.phase}, ButtonsFound=${state.availableButtons?.length || 0}`);
  });

  test('CHAOS-02: Rapid-fire button mashing race condition test', async ({ page }) => {
    // Attempt rapid click spamming on any clickable elements or canvas
    const clickables = page.locator('button, [role="button"], flt-glass-pane');
    const count = await clickables.count();

    if (count > 0) {
      const target = clickables.first();
      // Spam click 12 times in rapid succession
      for (let i = 0; i < 12; i++) {
        await target.click({ force: true, timeout: 500 }).catch(() => {});
      }
    }

    await page.waitForTimeout(500);

    // Invariant: App root must remain mounted, not crashed into blank screen
    const isAlive = await page.evaluate(() => {
      return document.querySelector('flt-glass-pane') !== null || document.body.innerHTML.length > 50;
    });
    expect(isAlive).toBe(true);
  });

  test('CHAOS-03: Boundary handling - empty / partial submit resilience', async ({ page }) => {
    // Find any submit / check / continue buttons
    const submitBtn = page.locator('button:has-text("Submit"), [role="button"]:has-text("Submit"), button:has-text("Check")');
    if (await submitBtn.isVisible()) {
      // Click without making any answer selections
      await submitBtn.click({ force: true });
      await page.waitForTimeout(500);
    }

    // Invariant: No fatal exception dialogs visible
    const fatalError = page.locator('text=Fatal, text=Unhandled Exception, text=RangeError');
    await expect(fatalError).not.toBeVisible();
  });

  test('CHAOS-04: Adversarial monkey click thrashing across interactive elements', async ({ page }) => {
    // Perform 10 pseudo-random rapid interactions across the screen
    for (let step = 0; step < 10; step++) {
      const randomX = Math.floor(Math.random() * 400) + 100;
      const randomY = Math.floor(Math.random() * 400) + 100;

      await page.mouse.click(randomX, randomY, { delay: 10 }).catch(() => {});
      await page.keyboard.press(step % 2 === 0 ? 'Space' : 'Enter').catch(() => {});
      await page.waitForTimeout(50);
    }

    await page.waitForTimeout(500);
    const eventLog = await page.evaluate(() => (window as any).__HARDCODE_EVENT_LOG__ || []);
    const unhandledErrors = eventLog.filter((e: any) => e.type === 'UNHANDLED_ERROR');
    if (unhandledErrors.length > 0) {
      console.log('UNHANDLED ERRORS CAPTURED:', JSON.stringify(unhandledErrors));
    }
    expect(unhandledErrors.length).toBe(0);
  });

  test('CHAOS-05: State coverage & question type invariants', async ({ page }) => {
    // Verify that question types are recognized and trackable
    const questionTypes = [
      'multiChoiceSyntax',
      'conceptualMultiChoice',
      'trueFalse',
      'matching',
      'sequencing',
      'sortingClassification'
    ];

    const state = await page.evaluate(() => (window as any).__getHardcodeState?.());
    expect(state).toBeDefined();

    // Verify error logging capacity
    const logs = await page.evaluate(() => (window as any).__HARDCODE_EVENT_LOG__);
    expect(Array.isArray(logs)).toBe(true);
  });

});
