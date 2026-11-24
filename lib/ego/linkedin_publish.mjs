const postEditor = 'dialog[open] div.ProseMirror[contenteditable="true"][role="textbox"]';
const headline = "textarea#article-editor-headline__textarea";
const articleEditor = '.ProseMirror[aria-label="글 에디터 콘텐츠"]';

const unconfirmed = {
  ok: true,
  url: null,
  unconfirmed: true,
  reason: "게시 버튼을 눌렀지만 결과를 확인하지 못했습니다. LinkedIn에서 게시 여부를 확인하세요.",
};
let publishClickPendingOrSent = false;

async function pressButton(page, { labels, scope = "body", selector, expected, publishing = false }) {
  // A lost response to the final click can leave its outcome unknown.
  if (publishing) publishClickPendingOrSent = true;
  const validationError = await page.evaluate(({ labels, scope, selector, expected }) => {
    const buttons = [...document.querySelectorAll(scope + " button")]
      .filter(button => labels.includes(button.innerText.trim()));
    if (buttons.length !== 1 || buttons[0].matches(":disabled") || buttons[0].getAttribute("aria-disabled") === "true") {
      return `실행 가능한 ${labels.join("/")} 버튼을 하나로 확인하지 못함`;
    }
    const normalize = value => value.replace(/\s+/g, " ").trim();
    if (selector && !normalize(document.querySelector(selector)?.innerText ?? "").includes(expected)) {
      return "입력한 게시물 본문을 확인하지 못함";
    }
    buttons[0].click();
    return null;
  }, { labels, scope, selector, expected });
  if (validationError) {
    if (publishing) publishClickPendingOrSent = false;
    throw new Error(validationError);
  }
}

async function publishPost(page, { text, probe }) {
  await page.click('loc=role:button[name="글 올리기"]', { label: "게시물 작성 창 열기" });
  await page.waitForTimeout(1000);

  if (probe) {
    const elements = await page.evaluate(selector => {
      const editor = !!document.querySelector(selector);
      const publish_button = [...document.querySelectorAll("dialog[open] button")]
        .some(button => button.innerText.trim() === "게시물");
      const dialog = document.querySelector("dialog[open]");
      if (dialog) {
        const target = dialog.contains(document.activeElement) ? document.activeElement : dialog;
        target.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", code: "Escape", bubbles: true }));
        if (dialog.open) dialog.requestClose();
      }
      return { editor, publish_button };
    }, postEditor);
    return { ok: true, probe: elements };
  }

  if (!text?.trim()) throw new Error("게시물 본문이 비어 있음");
  const prefix = Array.from(text.replace(/\s+/g, " ").trim()).slice(0, 30).join("");
  const editorEmpty = await page.evaluate(selector => {
    const editor = document.querySelector(selector);
    return editor && !editor.innerText.trim();
  }, postEditor);
  if (!editorEmpty) throw new Error("비어 있는 게시물 편집기를 확인하지 못함");
  await page.focus(postEditor);
  await page.keyboard.paste(text);
  await pressButton(page, {
    labels: ["게시물"], scope: "dialog[open]", selector: postEditor, expected: prefix, publishing: true,
  });

  for (let attempt = 0; attempt < 15; attempt++) {
    await page.waitForTimeout(1000);
    if (!await page.evaluate(() => !!document.querySelector("dialog[open]"))) {
      const url = await findPostUrl(page, prefix);
      return url ? { ok: true, url } : unconfirmed;
    }
  }
  return unconfirmed;
}

async function findPostUrl(page, prefix) {
  await page.goto("https://www.linkedin.com/in/me/recent-activity/all/", { timeout: 40000 });
  await page.waitForTimeout(3000);
  return page.evaluate(prefix => {
    const normalize = value => value.replace(/\s+/g, " ").trim();
    const expected = normalize(prefix);
    const selector = 'a[href*="urn:li:activity:"]';
    const activityId = link => link.href.match(/urn:li:activity:(\d+)/)?.[1];
    if (!expected) return null;
    for (const link of document.querySelectorAll(selector)) {
      const id = activityId(link);
      if (!id) continue;
      for (let item = link.parentElement; item && item !== document.body; item = item.parentElement) {
        if ([...item.querySelectorAll(selector)].some(other => activityId(other) !== id)) break;
        if (normalize(item.innerText ?? "").includes(expected)) {
          return `https://www.linkedin.com/feed/update/urn:li:activity:${id}/`;
        }
      }
    }
    return null;
  }, prefix);
}

async function publishArticle(page, { title, body, newsletter_name, probe }) {
  await page.goto("https://www.linkedin.com/article/new/", { timeout: 40000 });
  let elements;
  for (let attempt = 0; attempt <= 12; attempt++) {
    if (attempt > 0) await page.waitForTimeout(1000);
    elements = await page.evaluate(({ headline, articleEditor }) => {
      const buttons = [...document.querySelectorAll("button")];
      const candidates = buttons.filter(button => button.innerText.trim().includes("\n"));
      return {
        headline: !!document.querySelector(headline),
        editor: !!document.querySelector(articleEditor),
        next_button: buttons.some(button => button.innerText.trim() === "다음"),
        author_button: candidates.length === 1 ? candidates[0].innerText.replace(/\s+/g, " ").trim() : null,
        author_candidates: candidates.slice(0, 5).map(button => button.innerText.trim()),
      };
    }, { headline, articleEditor });
    if (elements.headline && elements.editor && elements.next_button && elements.author_button) break;
  }

  if (probe) return { ok: true, probe: elements };
  if (newsletter_name && !elements.author_button?.includes(newsletter_name)) {
    throw new Error("뉴스레터 선택이 다름");
  }
  if (!elements.author_button) throw new Error("글 작성자 버튼을 하나로 확인하지 못함");
  if (!elements.headline || !elements.editor || !elements.next_button) throw new Error("글 편집 화면을 확인하지 못함");
  if (!title?.trim() || !body?.trim()) throw new Error("글 제목 또는 본문이 비어 있음");

  await page.fill(headline, title);
  await page.focus(articleEditor);
  await page.keyboard.paste(body);
  const filled = await page.evaluate(({ headline, title, articleEditor, body }) => {
    const normalize = value => value.replace(/\s+/g, " ").trim();
    return document.querySelector(headline)?.value === title &&
      normalize(document.querySelector(articleEditor)?.innerText ?? "") === normalize(body);
  }, { headline, title, articleEditor, body });
  if (!filled) throw new Error("입력한 글 제목 또는 본문을 확인하지 못함");

  const existingLinks = await page.evaluate(() => [...document.querySelectorAll('a[href*="/pulse/"]')].map(link => link.href));
  await pressButton(page, { labels: ["다음"] });
  await page.waitForTimeout(1000);
  await pressButton(page, { labels: ["게시", "발행"], scope: ':is(dialog[open], [role="dialog"])', publishing: true });
  for (let attempt = 0; attempt < 15; attempt++) {
    await page.waitForTimeout(1000);
    const url = await page.evaluate(previous => {
      const pulse = href => /^https:\/\/www\.linkedin\.com\/pulse\/[^/?#]+/.test(href);
      if (pulse(location.href)) return location.href;
      return [...document.querySelectorAll('a[href*="/pulse/"]')]
        .map(link => link.href).find(href => pulse(href) && !previous.includes(href)) ?? null;
    }, existingLinks);
    if (url) return { ok: true, url };
  }
  return unconfirmed;
}

let task;
let result;
try {
  const { kind, login_id } = PUBLISH;
  if (!login_id?.trim()) throw new Error("계정 정보 없음");
  if (!["post", "article"].includes(kind)) throw new Error("게시 유형이 올바르지 않습니다.");

  task = await taskSpace(`imPD LinkedIn 게시 ${new Date().toISOString()}`);
  const page = task.page("p1");
  const profile = await (async () => {
    await page.goto("https://www.linkedin.com/feed/", { timeout: 40000 });
    return page.evaluate(async () => {
      const csrf = document.cookie.match(/(?:^|;\s*)JSESSIONID="?([^";]+)/)?.[1];
      if (!csrf) return null;
      const response = await fetch("/voyager/api/me", {
        credentials: "include",
        headers: { "csrf-token": csrf, accept: "application/json" },
      });
      if (!response.ok) return null;
      return (await response.json())?.miniProfile ?? null;
    });
  })().catch(() => null);
  if (profile?.publicIdentifier !== login_id) throw new Error("로그인된 LinkedIn 계정이 다름");

  result = kind === "post" ? await publishPost(page, PUBLISH) : await publishArticle(page, PUBLISH);
} catch (error) {
  const suffix = PUBLISH.kind === "article" && !PUBLISH.probe ? " · LinkedIn 글 임시저장에 남아 있을 수 있음" : "";
  result = publishClickPendingOrSent ? unconfirmed : { ok: false, reason: String(error.message ?? error) + suffix };
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
