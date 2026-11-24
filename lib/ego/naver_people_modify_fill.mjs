const space_name = FILL.probe
  ? `imPD 네이버 인물정보 수정 신청 점검 ${FILL.account_id}`
  : `imPD 네이버 인물정보 수정 신청 ${FILL.account_id}`;
const origin = "https://myprofile.naver.com";
const enameInput = 'input[name="enName"]';
const siteInput = 'input[placeholder="URL을 입력해 주세요."]';
const siteButtons = {
  open: "사이트 추가",
  add: "추가하기",
  cancel: "취소"
};
let task;
let result;

async function until(page, read, reason) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const value = await read();
    if (value) return value;
    await page.waitForTimeout(250);
  }
  if (reason) throw new Error(reason);
  return false;
}

function atStep(page, type) {
  return page.evaluate(({ origin, type }) => {
    return location.origin === origin && location.pathname === "/infomanagement" &&
      (type === null ? !location.search : new URLSearchParams(location.search).get("type") === type);
  }, { origin, type });
}

function hasSiteButton(page, text) {
  return page.evaluate(text => [...document.querySelectorAll("button")].some(button =>
    button.getClientRects().length && button.innerText.trim() === text), text);
}

async function clickSiteButton(page, action) {
  if (!await atStep(page, "defaultinfo")) throw new Error("기본정보 화면을 벗어났습니다.");
  const selector = await page.evaluate(text => {
    const buttons = [...document.querySelectorAll("button")].filter(button =>
      button.getClientRects().length && button.innerText.trim() === text);
    if (buttons.length !== 1) return null;
    for (const node of document.querySelectorAll("[data-impd-site-button]")) {
      node.removeAttribute("data-impd-site-button");
    }
    buttons[0].setAttribute("data-impd-site-button", text);
    return `button[data-impd-site-button="${text}"]`;
  }, siteButtons[action]);
  if (!selector) throw new Error(`'${siteButtons[action]}' 버튼을 확인할 수 없습니다.`);
  await page.click(selector);
}

async function openBasicInfo(page) {
  await page.goto(origin + "/infomanagement", { timeout: 40000 });

  await until(page, () => atStep(page, null), "수정 대상 선택 화면을 열 수 없습니다.");
  const target = await until(page, () => page.evaluate(({ name, job }) => {
    const matches = [...document.querySelectorAll("li")].filter(row => {
      if (!row.getClientRects().length) return false;
      const texts = [...row.querySelectorAll("*")]
        .filter(node => node.closest("li") === row && node.getClientRects().length)
        .map(node => node.innerText?.trim());
      return texts.includes(name) && texts.includes(job);
    });
    const rows = matches.filter(row => !matches.some(other => other !== row && row.contains(other)));
    if (!rows.length) return false;
    if (rows.length !== 1) return "ambiguous";
    rows[0].setAttribute("data-impd-person", "");
    return "matched";
  }, { name: FILL.display_name.trim(), job: FILL.job.trim() }), "수정 대상 이름과 직업을 한 항목에서 확인할 수 없습니다.");
  if (target !== "matched") throw new Error("수정 대상 이름과 직업을 한 항목에서 확인할 수 없습니다.");

  await page.click("li[data-impd-person]");
  if (!await atStep(page, null)) throw new Error("수정 대상 선택 화면을 벗어났습니다.");
  await page.click('loc=role:button[name="다음"]');
  await until(page, () => atStep(page, "defaultinfo"), "인물정보 입력 화면을 열 수 없습니다.");
}

function inputVisible(page, selector) {
  return page.evaluate(selector => {
    const inputs = [...document.querySelectorAll(selector)].filter(input => input.getClientRects().length);
    return inputs.length === 1;
  }, selector);
}

function siteMatches(page, value) {
  return page.evaluate(({ value, host, siteInput }) => {
    if ([...document.querySelectorAll(siteInput)].some(input => input.getClientRects().length)) return null;
    const button = [...document.querySelectorAll("button")].find(node =>
      node.getClientRects().length && node.innerText.trim() === "사이트 추가");
    let section = button?.parentElement;
    while (section && section !== document.body) {
      const text = section.innerText;
      if (section.hasAttribute("data-impd-site-list") || text.includes("사이트 정보를 입력해 주세요")) {
        section.setAttribute("data-impd-site-list", "");
        const tokens = text.split(/[\s,<>()[\]{}]+/);
        return tokens.filter(token => {
          if (token === value || token === host) return true;
          try { return new URL(token).hostname === host; } catch { return false; }
        }).length;
      }
      section = section.parentElement;
    }
    return null;
  }, { value, host: new URL(value).hostname, siteInput });
}

async function fillSite(page, value) {
  const previous = await siteMatches(page, value);
  if (previous === null) return false;
  await clickSiteButton(page, "open");
  await until(page, () => inputVisible(page, siteInput), "사이트 추가 레이어를 열 수 없습니다.");
  await page.fill(siteInput, value);
  await clickSiteButton(page, "add");

  const added = await until(page, async () => {
    const matches = await siteMatches(page, value);
    return matches !== null && matches > previous;
  });
  if (added) return true;

  if (await hasSiteButton(page, siteButtons.cancel)) {
    await clickSiteButton(page, "cancel");
  }
  await until(page, async () => !await inputVisible(page, siteInput), "사이트 추가 레이어를 닫을 수 없습니다.");
  return false;
}

try {
  if (!FILL.display_name?.trim() || !FILL.job?.trim()) throw new Error("수정 대상 이름과 직업이 필요합니다.");
  task = await taskSpace(space_name);
  const page = task.page("p1");
  await openBasicInfo(page);
  const hasEname = await until(page, () => inputVisible(page, enameInput));
  const hasSiteAdd = await until(page, () => hasSiteButton(page, siteButtons.open));

  if (FILL.probe) {
    await task.finish({ keep: [] });
    result = { ok: true, probe: { ename: hasEname, site_add: hasSiteAdd } };
  } else {
    if (!hasEname || !hasSiteAdd) throw new Error("기본정보 입력 칸과 사이트 추가 버튼을 확인할 수 없습니다.");
    const filled = [];
    const failed = [];
    if (FILL.ename) {
      await page.fill(enameInput, "");
      await page.fill(enameInput, FILL.ename);
      const matches = await page.evaluate(({ selector, value }) =>
        document.querySelector(selector)?.value === value, { selector: enameInput, value: FILL.ename });
      if (!matches) throw new Error("영문명 입력 값을 확인할 수 없습니다.");
      filled.push({ field: "ename", value: FILL.ename });
    }
    for (const value of FILL.sites) {
      if (await fillSite(page, value)) {
        filled.push({ field: "sites", value });
      } else {
        failed.push({ value, reason: "사이트 목록에서 추가된 주소를 확인할 수 없습니다." });
      }
    }
    if (!await atStep(page, "defaultinfo")) throw new Error("기본정보 화면을 벗어났습니다.");
    await page.evaluate(() => window.scrollTo(0, 0));
    await task.handOff();
    result = { ok: true, space_id: task.spaceId, space_name, filled, failed };
  }
} catch (error) {
  let reason = String(error.message ?? error);
  if (task) {
    try {
      await task.finish({ keep: [] });
    } catch (cleanupError) {
      reason += ` (ego 작업 공간 정리 실패: ${cleanupError.message ?? cleanupError})`;
    }
  }
  result = { ok: false, reason };
}
console.log("EGO_RESULT " + JSON.stringify(result));
