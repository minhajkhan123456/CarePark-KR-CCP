// Assemble the single-file site: website/index.html (deploy anywhere) and website/dist/artifact.html
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
const W = new URL("../website/", import.meta.url).pathname;
const r = f => readFileSync(W + f, "utf8");
const page = r("src/page.html")
  .replace("/*KB*/", r("kb.json")).replace("/*RESULTS*/", r("results.json")).replace("/*SITE*/", r("site.json"))
  .replace("/*ENGINE*/", () => r("engine.js")).replace("/*APP*/", () => r("src/app.js")).replace("/*TWIN*/", () => r("src/twin.js"));
mkdirSync(W + "dist", { recursive: true });
writeFileSync(W + "dist/artifact.html", page);
writeFileSync(W + "index.html", `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}[hidden]{display:none!important}img{max-width:100%}</style>\n</head>\n<body>\n${page}\n</body>\n</html>\n`);
console.log("built", Math.round(page.length / 1024), "KB");
