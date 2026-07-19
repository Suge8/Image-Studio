import { writable, derived } from 'svelte/store';

export const I18N = {
  en: {
    "nav.wall": "Gallery", "nav.features": "Features", "nav.demo": "Demo", "nav.download": "Download",
    "h1.a": "AI image", "h1.b": "workbench",
    "hero.sub": "Ultra-light. Built for fast inspiration. Reuses your local ChatGPT login, with API support.",
    "cta.dl": "Download for macOS", "cta.gh": "Github",
    "hero.meta": "macOS 15+ · 2.4 MB · open source & free",
    "wall.h": "Where one sentence can go",
    "wall.cap": "All generated with Image Studio. Style is your call.",
    "demo.h": "As many as you want",
    "demo.p": "No cap on parallel runs. Maximum throughput.",
    "f1.h": "Free with your ChatGPT subscription",
    "f1.p": "Reuses your local Codex login—no new key, no new bill. Prefer an API? Any OpenAI-Images-compatible endpoint works, with the per-image price shown before you spend.",
    "f2.h": "Parallel generations",
    "f2.p": "One request per image, all at once. Retry only the one that failed. Start the next run while this one is still going.",
    "f3.h": "Your folder is the history",
    "f3.p": "Pick a folder and results land there. Space to Quick Look, drag to Finder, right-click to use as a reference. No database, no account.",
    "f4.h": "Controls match the backend",
    "f4.p": "Size options are only what each backend actually accepts—checked against live endpoints. What Codex cannot do, the API channel can.",
    "tips.h": "Shortcuts worth knowing",
    "t1": "Paste references with ⌘V",
    "t2": "Quick Look with Space",
    "t3": "Right-click to iterate",
    "t4": "Retry just the failed one",
    "dl.h": "Download Image Studio", "dl.btn": "Download v0.3.0",
    "dl.note": "Ad-hoc signed. First launch: right-click the app and choose Open.",
    "ft.made": "Made by", "ft.rel": "Releases", "ft.iss": "Issues",
    "title": "Image Studio · AI image workbench"
  },
  zh: {
    "nav.wall": "画廊", "nav.features": "功能", "nav.demo": "演示", "nav.download": "下载",
    "h1.a": "AI 绘图", "h1.b": "工作台",
    "hero.sub": "极致轻量，高效灵感。复用本机 ChatGPT 登录，支持 API 调用",
    "cta.dl": "下载 macOS 版", "cta.gh": "Github",
    "hero.meta": "macOS 15+ · 2.4 MB · 开源免费",
    "wall.h": "一句话能走多远",
    "wall.cap": "全部由 Image Studio 生成，风格你说了算。",
    "demo.h": "画多少张你说了算",
    "demo.p": "并行数量无上限，极致效率",
    "f1.h": "ChatGPT 订阅直接用",
    "f1.p": "复用本机 Codex 登录，不用另买 key。也可以走 API：兼容 OpenAI Images 的端点均可，生成前显示每张单价。",
    "f2.h": "多张并行",
    "f2.p": "一图一请求，同时发出。失败只重试那一张；上一轮没结束，下一轮也能开。",
    "f3.h": "文件夹就是历史",
    "f3.p": "结果落在你选的目录。空格预览，拖进 Finder，右键当作参考图。没有数据库，没有账号。",
    "f4.h": "选项和后端一致",
    "f4.p": "尺寸只保留后端真正接受的值，均经线上接口核实。Codex 做不到的，交给 API 通道。",
    "tips.h": "常用操作",
    "t1": "⌘V 粘贴参考图",
    "t2": "空格快速预览",
    "t3": "右键基于结果迭代",
    "t4": "失败的单独重试",
    "dl.h": "下载 Image Studio", "dl.btn": "下载 v0.3.0",
    "dl.note": "Ad-hoc 签名。首次打开请右键应用，选择「打开」。",
    "ft.made": "作者", "ft.rel": "版本", "ft.iss": "问题反馈",
    "title": "Image Studio · AI 绘图工作台"
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
