#!/usr/bin/env bash
# Нэг коммандаар index.html-ийн бүх шалгалтыг гүйцэтгэнэ (JS syntax, CSS хаалт, огнооны алдаа).
# Ашиглах: bash tools/check.sh
cd "$(dirname "$0")/.."
FILE="index.html"
FAIL=0

echo "== 1) <script> JS syntax =="
python3 - "$FILE" <<'PY'
import re,sys
html = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"<script>(.*)</script>", html, re.S)
open("/tmp/_festival_check.js","w",encoding="utf-8").write(m.group(1))
PY
if node --check /tmp/_festival_check.js 2>&1; then
  echo "OK: JS syntax зөв"
else
  echo "FAIL: JS syntax алдаатай"; FAIL=1
fi

echo "== 2) <style> CSS хаалтын тэнцвэр =="
if python3 - "$FILE" <<'PY'
import re,sys
html = open(sys.argv[1], encoding="utf-8").read()
style = re.search(r"<style>(.*)</style>", html, re.S).group(1)
o,c = style.count("{"), style.count("}")
print(f"open={o} close={c}")
sys.exit(0 if o==c else 1)
PY
then
  echo "OK: CSS хаалт тэнцвэртэй"
else
  echo "FAIL: CSS хаалт тэнцвэргүй"; FAIL=1
fi

echo "== 3) RAW өгөгдлийн огноо/section шалгах =="
if node - "$FILE" <<'JS'
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const rawMatch = html.match(/const RAW = (\[[\s\S]*?\n\]);/);
const secMatch = html.match(/const SECTIONS = (\[[\s\S]*?\n\]);/);
if (!rawMatch) { console.log("FAIL: RAW массив олдсонгүй"); process.exit(1); }
if (!secMatch) { console.log("FAIL: SECTIONS массив олдсонгүй"); process.exit(1); }
const RAW = eval(rawMatch[1]);
const SECTIONS = eval(secMatch[1]);
const YEAR = 2026;
function parsePeriod(str){
  const m = [...str.matchAll(/(\d{1,2})\.(\d{1,3})/g)];
  const toDate=(a,b)=> new Date(YEAR, parseInt(a,10)-1, parseInt(b,10));
  if(!m.length) return {start:null,end:null};
  const start = toDate(m[0][1], m[0][2]);
  const end = m.length>1 ? toDate(m[1][1], m[1][2]) : start;
  return {start,end};
}
let bad = 0;
RAW.forEach((r,i)=>{
  const p = parsePeriod(r[2]);
  if(!p.start || isNaN(p.start) || isNaN(p.end)) { console.log("BAD DATE, row", i+1, r[2]); bad++; }
  if(!(r[0]>=1 && r[0]<=SECTIONS.length)) { console.log("BAD SECTION id, row", i+1, r[0]); bad++; }
});
console.log(`Нийт мөр: ${RAW.length}, алдаатай: ${bad}`);
process.exit(bad ? 1 : 0);
JS
then
  echo "OK: RAW огноо/section бүгд зөв"
else
  echo "FAIL: RAW дотор алдаа бий"; FAIL=1
fi

echo "=================================="
if [ "$FAIL" -eq 0 ]; then
  echo "✅ БҮГД ЗӨВ — commit хийж болно."
else
  echo "❌ АЛДАА ОЛДЛОО — дээрх мөрүүдийг заавал засаад дахин ажиллуул."
fi
exit $FAIL
