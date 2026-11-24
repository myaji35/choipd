const { platform, account_handle } = CHECK;
let task;
let result;

try {
  task = await taskSpace(`imPD 채널 점검 ${platform} ${new Date().toISOString()}`);
  const page = task.page("p1");
  await page.goto("https://myprofile.naver.com/main", { timeout: 40000 });
  await page.waitForTimeout(2000);
  const login_id = await page.evaluate(() => {
    if (location.origin !== "https://myprofile.naver.com") return null;
    return document.body.innerText.match(/(?:^|\s)([A-Za-z0-9_.-]+)님\s*로그아웃/)?.[1] ?? null;
  });
  const normalize = value => String(value ?? "").trim().toLowerCase();
  result = { logged_in: !!login_id, login_id, matches: !!login_id && normalize(login_id) === normalize(account_handle) };
} catch (error) {
  result = { platform, error: String(error.message ?? error) };
} finally {
  if (task) { try { await task.finish({ keep: [] }); } catch (error) { result = { platform, error: String(error.message ?? error) }; } }
}
console.log("EGO_RESULT " + JSON.stringify(result));
