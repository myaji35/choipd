const blogOrigin = "https://blog.naver.com";
const titleSection = ".se-section-documentTitle";
const bodySection = ".se-section-text";
const settingsButton = 'button[class*="publish_btn__"]';
const confirmButton = 'button[class*="confirm_btn__"]';
const unconfirmed = {
  ok: true,
  unconfirmed: true,
  reason: "발행 버튼을 눌렀지만 결과를 확인하지 못했습니다. 네이버 블로그에서 확인하세요.",
};
let publishClickPendingOrSent = false;

async function loginId(page, handle) {
  await page.goto(`${blogOrigin}/PostList.naver?blogId=${encodeURIComponent(handle)}`, { timeout: 40000 });
  return page.evaluate(() => {
    if (location.origin !== "https://blog.naver.com") return null;
    const frame = document.querySelector("#mainFrame")?.contentWindow;
    for (const view of [window, frame]) {
      if (!view || view.location.origin !== location.origin) continue;
      // userNaverId identifies the viewer. naverId and blogId identify the blog owner.
      if (typeof view.userNaverId === "string" && /^[A-Za-z0-9_.-]+$/.test(view.userNaverId.trim())) {
        return view.userNaverId.trim().toLowerCase();
      }
    }
    return null;
  });
}

async function editorAction(page, action, options = {}) {
  return page.evaluate(({ action, handle, titleSection, bodySection, settingsButton, options }) => {
    const frame = document.querySelector("#mainFrame");
    const doc = frame ? frame.contentDocument : document;
    if (!doc || location.origin !== "https://blog.naver.com") return { error: "네이버 블로그 글쓰기 화면을 확인하지 못했습니다." };
    const url = new URL(doc.URL);
    if (url.origin !== location.origin || !(url.pathname.toLowerCase() === `/${handle}/postwrite` ||
        (url.pathname === "/PostWriteForm.naver" && url.searchParams.get("blogId")?.toLowerCase() === handle))) {
      return { error: "대상 블로그의 새 글쓰기 화면을 확인하지 못했습니다." };
    }
    if (url.searchParams.has("logNo")) return { error: "기존 글 편집 화면입니다." };

    const visible = node => node.getClientRects().length && doc.defaultView.getComputedStyle(node).visibility === "visible";
    const find = selector => [...doc.querySelectorAll(selector)].filter(visible);
    const buttons = (selector, label) => find(selector).filter(button => button.innerText.trim() === label);
    const usable = button => !button.matches(":disabled") && button.getAttribute("aria-disabled") !== "true";
    const normalize = text => text.replace(/\s+/g, " ").trim();
    const read = selector => normalize(find(selector).flatMap(section =>
      [...section.querySelectorAll(".se-text-paragraph")].map(paragraph => paragraph.innerText)
    ).join(" "));

    const draftPrompt = [...doc.querySelectorAll("p, span, strong, h2, h3, div")]
      .find(node => !node.children.length && visible(node) && !node.closest(".se-component") &&
        /작성\s*중인\s*글|임시\s*저장한\s*글|임시\s*저장된\s*글/.test(node.innerText));
    if (draftPrompt) {
      if (action !== "inspect") return { error: "임시저장 글 복원 팝업을 닫지 못했습니다." };
      let modal = draftPrompt.parentElement;
      while (modal && modal !== doc.body && !buttons("button", "취소").some(button => modal.contains(button))) {
        modal = modal.parentElement;
      }
      const cancel = buttons("button", "취소").filter(button => modal && modal !== doc.body && modal.contains(button));
      const confirm = buttons("button", "확인").filter(button => modal?.contains(button));
      if (cancel.length !== 1 || confirm.length !== 1 || !usable(cancel[0])) {
        return { error: "임시저장 글 복원 취소 버튼을 확인하지 못했습니다." };
      }
      cancel[0].click();
      return { dismissed: true };
    }

    if (action === "inspect") {
      return { title: find(titleSection).length === 1, body: find(bodySection).length === 1,
        publish_button: buttons(settingsButton, "발행").length === 1 };
    }
    if (action === "focus") {
      const fields = find(options.selector);
      const paragraph = fields[0]?.querySelector(".se-text-paragraph");
      if (fields.length !== 1 || !paragraph || read(options.selector)) return { error: "비어 있는 제목 또는 본문 칸을 확인하지 못했습니다." };
      paragraph.click();
      const selection = doc.getSelection();
      if (!fields[0].contains(doc.activeElement) &&
          !(doc.activeElement?.isContentEditable && fields[0].contains(selection?.anchorNode))) {
        return { error: "제목 또는 본문에 입력할 위치를 확인하지 못했습니다." };
      }
      return {};
    }
    const candidates = buttons(options.selector, "발행");
    if (candidates.length !== 1 || !usable(candidates[0])) return { error: "실행 가능한 발행 버튼을 하나로 확인하지 못했습니다." };
    if (read(titleSection) !== normalize(options.title) || read(bodySection) !== normalize(options.body)) {
      return { error: "입력한 글 제목 또는 본문을 확인하지 못했습니다." };
    }
    candidates[0].click();
    return {};
  }, { action, handle, titleSection, bodySection, settingsButton, options });
}

async function pressButton(page, selector, publishing = false) {
  if (publishing) publishClickPendingOrSent = true;
  const state = await editorAction(page, "press", { selector, title: PUBLISH.title, body: PUBLISH.body });
  if (state.error) {
    if (publishing) publishClickPendingOrSent = false;
    throw new Error(state.error);
  }
}

async function findPostUrl(page) {
  for (let attempt = 0; attempt < 15; attempt++) {
    await page.waitForTimeout(1000);
    const url = await page.evaluate(handle => {
      for (const href of [location.href, document.querySelector("#mainFrame")?.contentDocument?.URL]) {
        if (!href) continue;
        const current = new URL(href);
        if (current.origin !== "https://blog.naver.com") continue;
        const direct = current.pathname.match(/^\/([A-Za-z0-9_.-]+)\/(\d+)\/?$/);
        if (direct?.[1].toLowerCase() === handle) return `https://blog.naver.com/${handle}/${direct[2]}`;
        const id = current.searchParams.get("logNo");
        if (current.pathname === "/PostView.naver" && current.searchParams.get("blogId")?.toLowerCase() === handle &&
            current.searchParams.get("isAfterWrite") === "true" && /^\d+$/.test(id ?? "")) {
          return `https://blog.naver.com/${handle}/${id}`;
        }
      }
      return null;
    }, handle);
    if (url) return url;
  }
  return null;
}

async function publish(page) {
  if (await loginId(page, handle).catch(() => null) !== handle) throw new Error("로그인 계정 불일치");
  await page.goto(`${blogOrigin}/${encodeURIComponent(handle)}/postwrite`, { timeout: 40000 });
  let state;
  for (let attempt = 0; attempt < 15; attempt++) {
    await page.waitForTimeout(1000);
    state = await editorAction(page, "inspect");
    if (state.title && state.body && state.publish_button) break;
  }
  if (state.error) throw new Error(state.error);
  const probe = { title: !!state.title, body: !!state.body, publish_button: !!state.publish_button };
  if (PUBLISH.probe) return { ok: true, probe };
  if (!Object.values(probe).every(Boolean)) throw new Error("글쓰기 화면을 확인하지 못했습니다.");
  if (!PUBLISH.title?.trim() || !PUBLISH.body?.trim()) throw new Error("글 제목 또는 본문이 비어 있습니다.");

  for (const [selector, value] of [[titleSection, PUBLISH.title], [bodySection, PUBLISH.body]]) {
    const focused = await editorAction(page, "focus", { selector });
    if (focused.error) throw new Error(focused.error);
    await page.keyboard.paste(value);
  }
  await pressButton(page, settingsButton);
  await page.waitForTimeout(1000);
  await pressButton(page, confirmButton, true);
  const url = await findPostUrl(page);
  return url ? { ok: true, url } : unconfirmed;
}

const handle = String(PUBLISH.account_handle ?? "").trim().toLowerCase();
let task;
let result;
try {
  if (!/^[a-z0-9_-][a-z0-9_.-]*$/.test(handle)) throw new Error("로그인 계정 불일치");
  task = await taskSpace(`imPD 네이버 블로그 게시 ${new Date().toISOString()}`);
  result = await publish(task.page("p1"));
} catch (error) {
  result = publishClickPendingOrSent ? unconfirmed : { ok: false, reason: String(error.message ?? error) };
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
