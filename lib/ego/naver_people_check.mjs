const platform = "naver_people";
let task;
let result;
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
} catch (error) {
  result = { platform, error: String(error.message ?? error) };
} finally {
  if (task) { try { await task.finish({ keep: [] }); } catch (error) { result = { platform, error: String(error.message ?? error) }; } }
}
console.log("EGO_RESULT " + JSON.stringify(result));
