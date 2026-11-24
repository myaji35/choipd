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
    if (result.logged_in) {
      const nav_badges = await page.evaluate(() => {
        const labels = Array.from(document.querySelectorAll("a[aria-label]"), anchor => anchor.getAttribute("aria-label"));
        const badge = pattern => {
          const count = labels.map(label => label.match(pattern)?.[1]).find(value => value !== undefined);
          return count === undefined ? null : Number(count.replaceAll(",", ""));
        };
        return {
          messages: badge(/^메시지, 새 알림 ([\d,]+)$/),
          notifications: badge(/^알림, 새 알림 ([\d,]+)$/),
        };
      }).catch(() => null);
      const readPage = async (url, includeLinks, linkSelector) => {
        try {
          await page.goto(url, { timeout: linkSelector ? 12000 : 40000 });
          await page.waitForTimeout(4000);
          const content = await page.evaluate(selector => {
            const main = document.querySelector("main") || document.body;
            const text = main.innerText;
            const anchors = main.querySelectorAll(selector || 'a[href*="/analytics/post-summary/"], a[href*="/pulse/"]');
            const links = Array.from(anchors, anchor => {
              if (!selector) return anchor.href;

              const url = new URL(anchor.href);
              return url.origin + url.pathname.replace(/\/+$/, "");
            });
            return {
              text: selector ? text.slice(0, 20000) : text.split(/\n소개\n\n웹접근성|\n새 글 보기|\n프로필 언어|\n함께 조회된 사람/, 1)[0].slice(0, 20000),
              links: selector ? [...new Set(links)] : links.slice(0, 60),
            };
          }, linkSelector ?? null);
          return includeLinks ? { url, ...content } : { url, text: content.text };
        } catch (error) {
          return { url, error: String(error.message ?? error) };
        }
      };
      const dashboard = await readPage("https://www.linkedin.com/dashboard/", false);
      const activity = await readPage("https://www.linkedin.com/in/me/recent-activity/all/", true);
      const pages = { dashboard, activity };
      pages.profile = await readPage("https://www.linkedin.com/in/me/", false);
      for (const section of ["experience", "education", "skills", "certifications"]) {
        pages[section] = await readPage(`https://www.linkedin.com/in/me/details/${section}/`, false);
      }
      pages.network = await readPage("https://www.linkedin.com/mynetwork/", false);
      pages.invitations = await readPage("https://www.linkedin.com/mynetwork/invitation-manager/received/", false);
      pages.newsletters = await readPage("https://www.linkedin.com/mynetwork/network-manager/newsletters/", true, 'a[href*="/newsletters/"]');
      const newsletterUrls = (pages.newsletters.links ?? []).filter(url =>
        url.startsWith("https://www.linkedin.com/newsletters/") && !url.includes("/mynetwork/")
      );
      pages.newsletter_pages = [];
      for (const url of newsletterUrls.slice(0, 5)) {
        pages.newsletter_pages.push(await readPage(url, true, 'a[href*="/pulse/"]'));
      }
      result.accounts[0].data = { ...result.accounts[0].data, pages, nav_badges };
    }
  }
} catch (error) {
  result = { platform, error: String(error.message ?? error) };
} finally {
  if (task) { try { await task.finish({ keep: [] }); } catch (error) { result = { platform, error: String(error.message ?? error) }; } }
}
console.log("EGO_RESULT " + JSON.stringify(result));
