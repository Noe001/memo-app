const { test, expect } = require('@playwright/test');

// 共通ロケーター
const emailInput = 'input[name="user[email]"]';
const passwordInput = 'input[name="user[password]"]';
const submitButton = 'button[type="submit"]';
const memoList = '#memo-list';
const sidebar = '.memo-sidebar, .sidebar-header';
const mainContent = 'main';

test.describe('メモ一覧の表示', () => {
  test.beforeEach(async ({ page }) => {
    // ログイン処理
    await page.goto('http://localhost:3000/users/sign_in');
    await page.fill(emailInput, 'a@b.c');
    await page.fill(passwordInput, 'password');
    await page.click(submitButton);
    await page.waitForURL('http://localhost:3000/memos');
  });

  test('memo-listがサイドバーのみに1つだけ存在する', async ({ page }) => {
    // memo-listが1つだけ存在する
    await expect(page.locator(memoList)).toHaveCount(1);

    // サイドバー内に存在することを確認
    await expect(page.locator(sidebar).locator(memoList)).toHaveCount(1);

    // メインコンテンツ直下やform-bodyの上には存在しないことを確認
    await expect(page.locator(mainContent).locator(memoList)).toHaveCount(0);
  });

  test.afterEach(async ({ page }) => {
    // テスト間の状態クリーンアップ
    await page.context().clearCookies();
  });
});
