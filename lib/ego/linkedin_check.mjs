const platform = "linkedin";
let task;
let result;
try {
  task = await taskSpace(`imPD 인물정보 점검 ${platform} ${new Date().toISOString()}`);
  const page = task.page("p1");
  await page.goto("https://www.linkedin.com/feed/", { timeout: 40000 });
  await page.waitForTimeout(3000);
  const currentUrl = await page.url();
  if (["/login", "/authwall", "/checkpoint", "/uas/"].some(part => currentUrl.includes(part))) {
    result = { platform, logged_in: false };
  } else {
    result = await page.evaluate(async () => {
      const csrf = document.cookie.match(/JSESSIONID="?([^";]+)/)?.[1];
      const response = await fetch("/voyager/api/me", { credentials: "include", headers: { "csrf-token": csrf, accept: "application/json" } });
      if (!response.ok) return { platform: "linkedin", logged_in: false };
      const json = await response.json();
      const mp = json.miniProfile;
      const clean = value => {
        if (value && typeof value === "object") {
          delete value.$anti_abuse_metadata;
          Object.values(value).forEach(clean);
        }
      };
      clean(json);
      return { platform: "linkedin", logged_in: true, accounts: [{ external_id: mp.dashEntityUrn || mp.entityUrn, display_name: `${mp.firstName} ${mp.lastName}`.trim(), headline: mp.occupation, login_id: mp.publicIdentifier, auth_status: null, profile_url: `https://www.linkedin.com/in/${encodeURIComponent(mp.publicIdentifier)}/`, data: json }] };
    });
  }
} catch (error) {
  result = { platform, error: String(error.message ?? error) };
} finally {
  if (task) { try { await task.finish({ keep: [] }); } catch (error) { result = { platform, error: String(error.message ?? error) }; } }
}
console.log("EGO_RESULT " + JSON.stringify(result));
