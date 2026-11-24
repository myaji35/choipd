const platform = "naver_people";
let task;
let result;
function defaultQueries(account) {
  const name = account.display_name?.trim();
  if (!name) return [];
  const office = account.data.people?.peopleOffice?.[0]?.name;
  const qualified = [office, account.headline]
    .filter(value => typeof value === "string" && value.trim())
    .map(value => name + " " + value.trim());
  return [name, ...qualified];
}

async function collectSearch(page, query) {
  const url = "https://search.naver.com/search.naver?where=nexearch&query=" + encodeURIComponent(query);
  try {
    await page.goto(url, { timeout: 15000 });
    await page.waitForTimeout(2500);
    const boxes = await page.evaluate(() => {
      const osFrom = link => {
        try {
          if (!link?.getAttribute("href")?.trim() || !link.href) return null;
          return new URL(link.href).searchParams.get("os");
        } catch {
          return null;
        }
      };
      const read = (root, selector) => root.querySelector(selector)?.innerText.trim() ?? "";
      const box = document.querySelector("section._au_people_content_wrap");
      const mainOs = osFrom(box?.querySelector('a[href*="os="]'));
      const subtitles = mainOs ? Array.from(box.querySelectorAll(".title_area .sub_title .txt"), node => node.innerText.trim()) : [];
      const main = mainOs ? {
        os: mainOs,
        name: read(box, ".title_area ._text"),
        job: subtitles.pop() ?? "",
        aliases: subtitles,
        profile_text: read(box, ".cm_content_area._cm_content_area_profile").slice(0, 3000)
      } : null;
      const same_name = Array.from(document.querySelectorAll("section._au_people_content_same_name li._content"), item => {
        const link = item.querySelector(".title_box .name a");
        return {
          os: osFrom(link),
          name: link?.innerText.trim() ?? "",
          details: Array.from(item.querySelectorAll(".title_box .sub_text"), node => node.innerText.trim()).filter(Boolean)
        };
      }).filter(person => person.os);
      return { main, same_name };
    });
    return { query, url, ...boxes };
  } catch (error) {
    return { query, error: String(error.message ?? error) };
  }
}

try {
  task = await taskSpace(`imPD 인물정보 점검 ${platform} ${new Date().toISOString()}`);
  const page = task.page("p1");
  await page.goto("https://myprofile.naver.com/main", { timeout: 40000 });
  await page.waitForTimeout(2000);
  result = await page.evaluate(async () => {
    const response = await fetch("https://api.myprofile.naver.com/api/auth-list?size=10000&page=0", { credentials: "include" });
    if (!response.ok) return { platform: "naver_people", logged_in: false };
    let json;
    try { json = await response.json(); } catch { return { platform: "naver_people", logged_in: false }; }
    if (json.success !== true) return { platform: "naver_people", logged_in: false };
    const login_id = document.body.innerText.match(/([A-Za-z0-9_.-]+)님\s*로그아웃/)?.[1] ?? null;
    const peopleDetails = await Promise.all(json.result.content.map(async item => {
      const id = item.people.id;
      const detail = await fetch(`https://api.myprofile.naver.com/api/people-select?peopleId=${id}`, { credentials: "include" });
      return (await detail.json()).result;
    }));
    const applications = Object.fromEntries(await Promise.all(["ING", "END"].map(async status => {
      let response;
      try {
        response = await fetch(`https://api.myprofile.naver.com/api/result-list?status=${status}&page=0`, { credentials: "include" });
      } catch {
        return [status, { error: "요청 실패" }];
      }
      if (!response.ok) return [status, { error: `HTTP ${response.status}` }];
      let json;
      try { json = await response.json(); } catch { return [status, { error: "JSON 해석 실패" }]; }
      if (json?.success !== true) return [status, { error: "API 응답 실패" }];
      return [status, json.result ?? null];
    })));
    const accounts = json.result.content.map((item, index) => {
      const id = item.people.id;
      return { external_id: String(id), display_name: item.people.name, headline: item.people.jobName1, auth_status: `${item.auth.relKind}/${item.auth.status}`, login_id, profile_url: `https://search.naver.com/search.naver?where=nexearch&pkid=1&os=${item.people.dss || id}&query=${encodeURIComponent(item.people.name)}`, data: { auth: item.auth, people: peopleDetails[index], dss: item.people.dss, applications } };
    });
    return { platform: "naver_people", logged_in: true, accounts };
  });
  const collected = new Map();
  for (const account of result.accounts ?? []) {
    const configuredQueries = INPUT.search_queries_by_account?.[account.external_id];
    const queries = Array.isArray(configuredQueries) ? configuredQueries : defaultQueries(account);
    const accountQueries = [...new Set(queries.map(query => query.trim()).filter(Boolean))].slice(0, 10);
    const results = [];
    for (const query of accountQueries) {
      if (!collected.has(query)) collected.set(query, await collectSearch(page, query));
      results.push(collected.get(query));
    }
    account.data.search = { checked_at: new Date().toISOString(), queries: accountQueries, results };
  }
} catch (error) {
  result = { platform, error: String(error.message ?? error) };
} finally {
  if (task) { try { await task.finish({ keep: [] }); } catch (error) { result = { platform, error: String(error.message ?? error) }; } }
}
console.log("EGO_RESULT " + JSON.stringify(result));
