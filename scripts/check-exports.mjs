import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const files = ["js/grid.js", "js/ui.js", "js/main.js", "js/combat.js", "js/unit.js"];

function exportsOf(src) {
  const names = new Set();
  for (const m of src.matchAll(/export\s+(?:async\s+)?(?:const|let|var|function|class)\s+(\w+)/g)) {
    names.add(m[1]);
  }
  for (const m of src.matchAll(/export\s*\{([^}]+)\}/g)) {
    for (const part of m[1].split(",")) {
      const bits = part.trim();
      if (!bits) continue;
      const as = bits.split(/\s+as\s+/);
      names.add((as[1] || as[0]).trim());
    }
  }
  return names;
}

function importsOf(src) {
  const list = [];
  for (const m of src.matchAll(/import\s*\{([^}]+)\}\s*from\s*['"]([^'"]+)['"]/g)) {
    const spec = m[2].replace(/\?.*$/, "").replace(/^\.\//, "");
    for (const part of m[1].split(",")) {
      const bits = part.trim();
      if (!bits) continue;
      const imported = bits.split(/\s+as\s+/)[0].trim();
      list.push({ name: imported, from: spec });
    }
  }
  return list;
}

const sources = {};
for (const rel of files) {
  sources[rel] = fs.readFileSync(path.join(root, rel), "utf8");
}

const exportMap = {};
for (const rel of files) {
  exportMap[rel] = exportsOf(sources[rel]);
}

let missing = 0;
const rows = [];
for (const rel of files) {
  for (const imp of importsOf(sources[rel])) {
    const targetRel = imp.from.startsWith("js/") ? imp.from : `js/${path.posix.basename(imp.from)}`;
    const exported = exportMap[targetRel];
    if (!exported) {
      rows.push(`${rel} -> ${targetRel} : 目标文件不在核对列表`);
      missing += 1;
      continue;
    }
    if (!exported.has(imp.name)) {
      rows.push(`缺口  ${rel}  import { ${imp.name} } from ${targetRel}  （未导出）`);
      missing += 1;
    } else {
      rows.push(`通过  ${rel}  import { ${imp.name} } from ${targetRel}`);
    }
  }
}

console.log("=== 各文件 export ===");
for (const rel of files) {
  console.log(rel + ":", [...exportMap[rel]].sort().join(", ") || "(无)");
}
console.log("\n=== import 对照 ===");
console.log(rows.join("\n"));
console.log(missing ? `\n结果：仍有 ${missing} 处缺口` : "\n结果：无缺口");
process.exit(missing ? 1 : 0);
