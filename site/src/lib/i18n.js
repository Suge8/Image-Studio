import { writable, derived } from 'svelte/store';

export const I18N = {
  en: {
    "nav.wall": "Gallery", "nav.features": "Features", "nav.demo": "Demo", "nav.download": "Download",
    "h1.a": "Prompt in.", "h1.b": "Pictures out.",
    "hero.sub": "Image Studio is a small native Mac app. Type one sentence, get a batch of images. It rides your ChatGPT login, costs nothing extra, and saves every result to a folder you own.",
    "cta.dl": "Download for macOS", "cta.gh": "View on GitHub",
    "hero.meta": "macOS 15+ · 2.4 MB · free and open source",
    "wall.h": "Where one sentence can go",
    "wall.cap": "All generated with Image Studio. Style is your call.",
    "demo.h": "Watch a batch land",
    "demo.p": "One prompt, four parallel requests. Each image drops into the gallery the moment it finishes.",
    "f1.h": "Free with your ChatGPT subscription",
    "f1.p": "The app reuses your local codex login. No new key, no new bill. Prefer a relay? Any OpenAI-Images-compatible endpoint works, with the per-image price shown before you spend.",
    "f2.h": "Every image gets its own lane",
    "f2.p": "One request per image, all in parallel. A failed slot retries by itself. Send the next batch while this one is still cooking.",
    "f3.h": "Your folder is the history",
    "f3.p": "Results land in a folder you pick. Press Space to Quick Look, drag one to Finder, right-click to use it as a reference. No database, no account, no lock-in.",
    "f4.h": "No placebo controls",
    "f4.p": "Size options match what each backend actually accepts, verified against live endpoints. What the Codex channel cannot do honestly routes to the relay.",
    "tips.h": "Small things, done right",
    "t1": "Paste references with ⌘V",
    "t2": "Quick Look with Space",
    "t3": "Right-click to iterate",
    "t4": "Retry just the failed slot",
    "steps.h": "Running in three minutes",
    "s1.h": "Install", "s2.h": "Connect", "s3.h": "Generate",
    "s2.p": "Run codex login once in Terminal, or paste a relay base URL and API key in Settings.",
    "s3.p": "Write a prompt, press ⌘↩. Finished images stream into the gallery one by one.",
    "dl.h": "Start your first batch", "dl.btn": "Download v0.3.0",
    "dl.note": "Ad-hoc signed. On first launch, right-click the app and choose Open.",
    "ft.made": "Made by", "ft.rel": "Releases", "ft.iss": "Issues",
    "title": "Image Studio · Prompt in, pictures out"
  },
  zh: {
    "nav.wall": "画廊", "nav.features": "功能", "nav.demo": "演示", "nav.download": "下载",
    "h1.a": "写一句。", "h1.b": "出一批。",
    "hero.sub": "Image Studio 是一个轻量的 macOS 原生应用。输入一句话，并行出一批图。复用你的 ChatGPT 登录，不额外花钱，每张结果都保存在你自己的文件夹里。",
    "cta.dl": "下载 macOS 版", "cta.gh": "GitHub 源码",
    "hero.meta": "macOS 15+ · 2.4 MB · 免费开源",
    "wall.h": "一句话能走多远",
    "wall.cap": "全部由 Image Studio 生成，风格你说了算。",
    "demo.h": "看一批图落地",
    "demo.p": "一句提示词，四路并行请求。每完成一张，画廊就进一张。",
    "f1.h": "ChatGPT 订阅直接用",
    "f1.p": "复用本机的 codex 登录，不用买新 key，没有新账单。想走中转也可以：任何兼容 OpenAI Images 的端点都行，生成前先看到每张单价。",
    "f2.h": "每张图各走各的道",
    "f2.p": "一张图一个请求，全部并行。失败的格子自己重试；上一批还在跑，下一批照发不误。",
    "f3.h": "文件夹就是历史",
    "f3.p": "结果落在你选的目录里。空格快速预览，拖进 Finder，右键用作参考图。没有数据库，没有账号，没有绑架。",
    "f4.h": "不做安慰剂选项",
    "f4.p": "尺寸选项只保留后端真正接受的值，全部对着线上接口实测过。Codex 通道做不到的，如实交给中转。",
    "tips.h": "小处见功夫",
    "t1": "⌘V 粘贴参考图",
    "t2": "空格快速预览",
    "t3": "右键基于结果迭代",
    "t4": "失败的单独重试",
    "steps.h": "三分钟跑起来",
    "s1.h": "安装", "s2.h": "接通", "s3.h": "生成",
    "s2.p": "终端跑一次 codex login，或在设置里填中转的 Base URL 和 API Key。",
    "s3.p": "写一句提示词，按 ⌘↩。图片完成一张，画廊进一张。",
    "dl.h": "开始你的第一批", "dl.btn": "下载 v0.3.0",
    "dl.note": "Ad-hoc 签名。首次打开请右键点击应用，选择「打开」。",
    "ft.made": "作者", "ft.rel": "版本", "ft.iss": "问题反馈",
    "title": "Image Studio · 写一句，出一批"
  }
};

const stored = typeof localStorage !== 'undefined' ? localStorage.getItem('lang') : null;
const initial = stored || (typeof navigator !== 'undefined' && navigator.language.startsWith('zh') ? 'zh' : 'en');

export const lang = writable(initial);
export const t = derived(lang, ($lang) => (key) => I18N[$lang][key] ?? key);

export function setLang(l) {
  lang.set(l);
  if (typeof localStorage !== 'undefined') localStorage.setItem('lang', l);
  if (typeof document !== 'undefined') {
    document.documentElement.lang = l === 'zh' ? 'zh-Hans' : 'en';
    document.title = I18N[l].title;
  }
}
