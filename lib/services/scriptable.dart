import '../config.dart';

/// Готовый скрипт для бесплатного приложения Scriptable (iPhone).
/// Он берёт тексты виджета с сервера по коду пары и рисует виджет.
String scriptableScript({required String code, required String memberId}) =>
    '''
// Виджет «V&V loving planning»: ближайшие выходные
const URL_BASE = "$kSupabaseUrl";
const KEY = "$kSupabaseAnonKey";
const CODE = "$code";
const ME = "$memberId";

const fm = FileManager.local();
const cachePath = fm.joinPath(fm.documentsDirectory(), "mywe-widget.json");

function todayKey() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, "0");
  return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
}

let data = null;
try {
  const req = new Request(URL_BASE + "/rest/v1/rpc/get_widget");
  req.method = "POST";
  req.headers = { apikey: KEY, "Content-Type": "application/json" };
  req.body = JSON.stringify({ p_code: CODE, p_member: ME });
  data = await req.loadJSON();
  if (data && typeof data === "object") {
    fm.writeString(cachePath, JSON.stringify(data));
  }
} catch (e) {
  if (fm.fileExists(cachePath)) data = JSON.parse(fm.readString(cachePath));
}

let lines = ["Откройте приложение «V&V loving planning», чтобы обновить"];
if (data && data[todayKey()]) lines = data[todayKey()];

const w = new ListWidget();
w.backgroundColor = new Color("#FFF3EA");
w.setPadding(14, 14, 14, 14);
const title = w.addText("БЛИЖАЙШИЕ ВЫХОДНЫЕ");
title.font = Font.boldSystemFont(10);
title.textColor = new Color("#8C7F78");
w.addSpacer(6);
lines.forEach((line, i) => {
  if (!line) return;
  const t = w.addText(line);
  t.font = (i === 0 || i === 2) ? Font.boldSystemFont(14) : Font.systemFont(14);
  t.textColor = new Color(i === 2 ? "#C2603F" : "#4A3F3A");
  t.minimumScaleFactor = 0.7;
  w.addSpacer(4);
});
w.refreshAfterDate = new Date(Date.now() + 2 * 60 * 60 * 1000);

if (config.runsInWidget) {
  Script.setWidget(w);
} else {
  await w.presentMedium();
}
Script.complete();
''';
