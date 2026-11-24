let task;
let result;
try {
  const { name, kind, decision, headline, login_id } = ACTION;
  if (!login_id?.trim()) throw new Error("계정 정보 없음");
  if (!name || !["connection", "newsletter"].includes(kind) || !["accept", "ignore"].includes(decision)) {
    throw new Error("신청 또는 승인 정보가 올바르지 않습니다.");
  }

  task = await taskSpace(`imPD LinkedIn 신청 처리 ${new Date().toISOString()}`);
  const page = task.page("p1");
  const loggedInAs = await (async () => {
    await page.goto("https://www.linkedin.com/feed/", { timeout: 40000 });
    return page.evaluate(async () => {
      const csrf = document.cookie.match(/(?:^|;\s*)JSESSIONID="?([^";]+)/)?.[1];
      if (!csrf) return null;
      const response = await fetch("/voyager/api/me", {
        credentials: "include",
        headers: { "csrf-token": csrf, accept: "application/json" },
      });
      if (!response.ok) return null;
      const profile = await response.json();
      return profile?.miniProfile?.publicIdentifier ?? null;
    });
  })().catch(() => null);
  if (loggedInAs !== login_id) throw new Error("로그인된 LinkedIn 계정이 다름");

  await page.goto("https://www.linkedin.com/mynetwork/invitation-manager/received/", { timeout: 40000 });
  await page.waitForTimeout(4000);

  const label = `${name}${kind === "connection" ? "님의" : "의"} 1촌 신청 ${decision === "accept" ? "수락" : "모른 척하기"}`;
  result = await page.evaluate(({ expectedLabel, expectedHeadline }) => {
    const normalize = s => s.replace(/\s+/g, " ").trim();
    const label = normalize(expectedLabel);
    const buttons = Array.from(document.querySelectorAll("button[aria-label]"))
      .filter(button => normalize(button.getAttribute("aria-label")) === label);
    if (buttons.length === 0) return { ok: false, reason: "버튼을 찾지 못함" };
    if (buttons.length > 1) return { ok: false, reason: "같은 이름 버튼이 여러 개" };

    const [button] = buttons;
    let card;
    let cardText;
    for (let parent = button.parentElement; parent; parent = parent.parentElement) {
      const text = normalize(parent.innerText ?? "");
      if (/님이 1촌이 되고 싶어 함|구독하라고 초대함/.test(text)) {
        card = parent;
        cardText = text;
        break;
      }
    }
    const acceptButtons = Array.from(card?.querySelectorAll("button[aria-label]") ?? [])
      .filter(button => normalize(button.getAttribute("aria-label")).endsWith("1촌 신청 수락"));
    if (!card || acceptButtons.length !== 1) {
      return { ok: false, reason: "신청 카드를 확인하지 못함" };
    }
    if (expectedHeadline && !cardText.includes(normalize(expectedHeadline))) {
      return { ok: false, reason: "직함이 달라 누르지 않음" };
    }

    button.click();
    return { ok: true };
  }, { expectedLabel: label, expectedHeadline: headline });

  if (result.ok) {
    await page.waitForTimeout(3000);
    const remains = await page.evaluate(expectedLabel => {
      const normalize = s => s.replace(/\s+/g, " ").trim();
      const label = normalize(expectedLabel);
      return Array.from(document.querySelectorAll("button[aria-label]"))
        .some(button => normalize(button.getAttribute("aria-label")) === label);
    }, label);
    if (remains) result = { ok: false, reason: "처리 후에도 신청 버튼이 남아 있음" };
  }
} catch (error) {
  result = { ok: false, reason: String(error.message ?? error) };
} finally {
  if (task) {
    try {
      await task.finish({ keep: [] });
    } catch (error) {
      console.error(String(error.message ?? error));
    }
  }
}
console.log("EGO_RESULT " + JSON.stringify(result));
