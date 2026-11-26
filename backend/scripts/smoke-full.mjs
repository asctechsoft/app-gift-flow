// Smoke test đầy đủ qua HTTP: node scripts/smoke-full.mjs [https://api-domain]
const B = process.argv[2] ?? process.env.API_BASE ?? 'http://localhost:3000';
let pass = 0, fail = 0;
const ok = (name, cond, extra = '') => { cond ? pass++ : fail++; console.log((cond ? 'PASS ' : 'FAIL ') + name + (cond ? '' : '  -> ' + extra)); };
const call = async (method, path, { auth, body, headers } = {}) => {
  const r = await fetch(B + path, {
    method,
    headers: { ...(body ? { 'Content-Type': 'application/json' } : {}), ...(auth ? { Authorization: 'Bearer ' + auth } : {}), ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
  let j = null; try { j = await r.json(); } catch {}
  return { s: r.status, j, h: r.headers };
};
const uuid = () => crypto.randomUUID();

// ---- hạ tầng / bảo mật
const ready = await call('GET', '/health/ready');
ok('health ready', ready.s === 200 && ready.j?.status === 'ok');
ok('header: no-store + HSTS + nosniff', ready.h.get('cache-control') === 'no-store' && /max-age/.test(ready.h.get('strict-transport-security') ?? '') && ready.h.get('x-content-type-options') === 'nosniff');
ok('Swagger /docs tắt', (await call('GET', '/docs')).s === 404);
ok('đường dẫn lạ bị nginx cắt (404)', (await call('GET', '/wp-login.php')).s === 404);
ok('thiếu token -> 401', (await call('GET', '/v1/events')).s === 401);

// ---- đăng nhập khách + refresh
const g = await call('POST', '/v1/auth/guest', { body: { device_id: uuid() } });
ok('guest auth', g.s === 200 && g.j?.access_token);
const A = g.j.access_token;
const me = await call('GET', '/v1/me', { auth: A });
ok('me + quota', me.s === 200 && me.j?.quota?.limit > 0);
const rf = await call('POST', '/v1/auth/refresh', { body: { refresh_token: g.j.refresh_token } });
ok('refresh xoay vòng', rf.s === 200 && rf.j?.refresh_token && rf.j.refresh_token !== g.j.refresh_token);
const reuse = await call('POST', '/v1/auth/refresh', { body: { refresh_token: g.j.refresh_token } });
ok('dùng lại refresh cũ bị từ chối', reuse.s === 401);
const B2 = (await call('POST', '/v1/auth/guest', { body: { device_id: uuid() } })).j.access_token;

// ---- sự kiện
const ev = uuid();
const e1 = await call('PUT', '/v1/events/' + ev, { auth: A, body: { name: 'Lễ cưới Minh & Trang', event_date: '2026-12-20', type: 'wedding', budget_vnd: 300000000 } });
ok('tạo sự kiện + ngân sách', e1.s === 200 && e1.j.budget_vnd === 300000000);
ok('người khác không đọc được sự kiện (404)', (await call('GET', '/v1/events/' + ev, { auth: B2 })).s === 404);
const evb = uuid();
ok('loại sự kiện mới (birthday)', (await call('PUT', '/v1/events/' + evb, { auth: A, body: { name: 'SN', event_date: '2026-12-21', type: 'birthday' } })).s === 200);

// ---- nhập tay (không AI) + giọng nói (AI parse) -> lưu
const manual = uuid();
const m = await call('PUT', '/v1/gifts/' + manual, { auth: A, body: { event_id: ev, guest_name: 'Chị Lan', relationship_label: 'Đồng nghiệp', amount_vnd: 1000000, status: 'confirmed', source: 'manual', side: 'mine' } });
ok('nhập tay: tên + tiền mừng (không dùng AI)', m.s === 200 && m.j.amount_vnd === 1000000);
const phrases = [
  ['Anh Long mừng hai triệu', 2000000, 'Anh Long'],
  ['Chị Mai năm trăm', 500000, 'Chị Mai'],
  ['Bác Hùng bạn bố mừng năm triệu', 5000000, 'Bác Hùng'],
  ['anh Nam 20k', 20000, 'Anh Nam'],
  ['Cô Hoa một triệu rưỡi', 1500000, 'Cô Hoa'],
];
const giftIds = [];
for (const [text, amount, name] of phrases) {
  const rid = uuid();
  const p = await call('POST', '/v1/ai/parse-gift', { auth: A, body: { event_id: ev, request_id: rid, text } });
  const good = p.s === 200 && p.j.data.amount === amount && p.j.data.guest_name === name && p.j.needs_review === false;
  ok(`AI: "${text}" -> ${name} ${amount}`, good, JSON.stringify(p.j?.data) + ' review=' + p.j?.needs_review);
  if (good) {
    const put = await call('PUT', '/v1/gifts/' + rid, { auth: A, body: { event_id: ev, guest_name: p.j.data.guest_name, relationship_label: p.j.data.relationship, amount_vnd: p.j.data.amount, status: 'confirmed', source: 'voice' } });
    ok('  lưu bản ghi giọng nói', put.s === 200);
    giftIds.push([rid, amount]);
  }
}
const ambiguous = await call('POST', '/v1/ai/parse-gift', { auth: A, body: { event_id: ev, request_id: uuid(), text: 'Anh Long mừng' } });
ok('thiếu số tiền -> cần kiểm tra, không bịa', ambiguous.j?.data?.amount === null && ambiguous.j?.needs_review === true);
const rid2 = uuid();
const p1 = await call('POST', '/v1/ai/parse-gift', { auth: A, body: { event_id: ev, request_id: rid2, text: 'Em Đức bạn thân hai triệu' } });
const p2 = await call('POST', '/v1/ai/parse-gift', { auth: A, body: { event_id: ev, request_id: rid2, text: 'Em Đức bạn thân hai triệu' } });
ok('idempotent theo request_id', JSON.stringify(p1.j) === JSON.stringify(p2.j));
ok('AI event của người khác -> 404', (await call('POST', '/v1/ai/parse-gift', { auth: B2, body: { event_id: ev, request_id: uuid(), text: 'Anh Long hai triệu' } })).s === 404);
ok('text quá dài -> 400', (await call('POST', '/v1/ai/parse-gift', { auth: A, body: { event_id: ev, request_id: uuid(), text: 'x'.repeat(600) } })).s === 400);

// ---- danh sách + thống kê theo người/quan hệ
const list = await call('GET', `/v1/events/${ev}/gifts?limit=50`, { auth: A });
ok('danh sách phong bì', list.s === 200 && list.j.items.length === 1 + giftIds.length, 'items=' + list.j?.items?.length);
const total = 1000000 + giftIds.reduce((a, [, x]) => a + x, 0);
const stats = await call('GET', `/v1/events/${ev}/stats`, { auth: A });
ok('thống kê: tổng tiền khớp', stats.s === 200 && stats.j.confirmed.total_vnd === total, `${stats.j?.confirmed?.total_vnd} vs ${total}`);
ok('thống kê theo quan hệ có dữ liệu', Array.isArray(stats.j.by_relationship) && stats.j.by_relationship.length > 0);
const del = await call('DELETE', '/v1/gifts/' + giftIds[0][0], { auth: A });
const stats2 = await call('GET', `/v1/events/${ev}/stats`, { auth: A });
ok('xóa mềm: tổng giảm đúng', del.s === 204 && stats2.j.confirmed.total_vnd === total - giftIds[0][1]);

// ---- kế hoạch cưới
const it = uuid();
ok('kế hoạch: khoản chi', (await call('PUT', '/v1/plan/items/' + it, { auth: A, body: { event_id: ev, category: 'venue', name: 'Nhà hàng', planned_vnd: 100000000, paid_vnd: 30000000 } })).j?.status === 'deposit');
ok('kế hoạch: khách dự kiến', (await call('PUT', '/v1/plan/guests/' + uuid(), { auth: A, body: { event_id: ev, name: 'Anh Long', party_size: 2, side: 'mine', invite_status: 'confirmed' } })).s === 200);
const sum = await call('GET', `/v1/events/${ev}/plan/summary`, { auth: A });
ok('kế hoạch: tổng hợp', sum.j?.planned_vnd === 100000000 && sum.j.budget_left_vnd === 200000000 && sum.j.guests.headcount === 2);
const stats3 = await call('GET', `/v1/events/${ev}/stats`, { auth: A });
ok('kế hoạch KHÔNG dính tiền mừng', stats3.j.confirmed.total_vnd === stats2.j.confirmed.total_vnd);
ok('IDOR kế hoạch -> 404', (await call('GET', `/v1/events/${ev}/plan/summary`, { auth: B2 })).s === 404);

// ---- xuất Excel
const ex = await call('POST', `/v1/events/${ev}/exports`, { auth: A, body: {} });
ok('xuất Excel tạo job', ex.s === 200 || ex.s === 201 || ex.s === 202, 'status ' + ex.s + ' ' + JSON.stringify(ex.j));

// ---- hạn mức
const me2 = await call('GET', '/v1/me', { auth: A });
ok('quota AI đã trừ đúng số lượt gọi AI', me2.j.quota.used >= phrases.length, JSON.stringify(me2.j.quota));

// dọn
await call('DELETE', '/v1/events/' + ev, { auth: A });
await call('DELETE', '/v1/events/' + evb, { auth: A });
console.log(`\nTỔNG: ${pass} pass, ${fail} fail`);
process.exit(fail ? 1 : 0);
