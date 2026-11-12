// End-to-end check of `firestore.rules` against the live Firebase project.
//
// This is a development harness, not part of the apps. It signs in the way the
// two clients do — anonymously for the customer, email + password for drivers —
// and walks the whole order lifecycle, plus the attacks the rules exist to stop.
//
//   node tool/rules_e2e.mjs        ->  "32/32 checks passed"
//
// Faithfulness matters more than coverage here, so two details are deliberate:
//
//   * writes go through `updateMask`, because `doc.update({...})` in the Dart
//     SDK is a masked write. A bare REST PATCH would *replace* the document and
//     change what `affectedKeys()` sees, which would fail a rule the app passes.
//   * the pool is read with a `runQuery` filtered on `driverUid == ''`, which is
//     the exact query the driver app runs. An unfiltered read of the whole
//     collection is denied by design (a list is checked against the query, not
//     against the documents), so reading it that way proves nothing.
//
// What it leaves behind: nothing visible. The orders it creates are deleted by
// the customer who owns them, the driver profiles are switched off (a client may
// not delete a profile — that is a rule), and the accounts it created are
// deleted at the end. The two `drivers/{uid}` documents remain, inactive and
// priced at zero, which is exactly what the customer board filters out.
//
// The API key below is the public client key from `firebase_options.dart`; it
// grants nothing beyond what the apps already can do.
const KEY = 'AIzaSyBVVinqJTl_zlfaW9_-pbY8oYPsIR9AMHA';
const PROJECT = 'sitirnati';
const DOCS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const AUTH = 'https://identitytoolkit.googleapis.com/v1/accounts';

const results = [];
function check(name, ok, detail) {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}  ${detail}`);
}

async function anon() {
  const r = await fetch(`${AUTH}:signUp?key=${KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error('anonymous sign-in failed: ' + JSON.stringify(j));
  return j;
}

async function emailUser(tag) {
  const email = `rules.${tag}.${Date.now()}@sitirnati.test`;
  const r = await fetch(`${AUTH}:signUp?key=${KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'RulesTest123!', returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error('email sign-up failed: ' + JSON.stringify(j));
  return { ...j, email };
}

async function dropUser(user) {
  await fetch(`${AUTH}:delete?key=${KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken: user.idToken }),
  });
}

const str = (v) => ({ stringValue: v });
const int = (v) => ({ integerValue: String(v) });
const dbl = (v) => ({ doubleValue: v });
const nil = { nullValue: 'NULL_VALUE' };

function newOrder(uid, over = {}) {
  const now = Date.now();
  return {
    customerUid: str(uid),
    customerName: str('قاعدة التجربة'),
    phone: str('0550123456'),
    placeName: str('حي 5 جويلية'),
    lat: dbl(36.7538),
    lng: dbl(3.0588),
    waterType: str('صالح للشرب'),
    volumeM3: int(10),
    price: int(4500),
    driverUid: str(''),
    driverName: str(''),
    driverPhone: str(''),
    status: str('sent'),
    createdAt: int(now),
    updatedAt: int(now),
    nearAt: nil,
    ...over,
  };
}

function profile(over = {}) {
  const now = Date.now();
  return {
    firstName: str('كريم'),
    lastName: str('بلقاسم'),
    email: str('driver@example.test'),
    phone: str('0661234567'),
    lat: dbl(36.75),
    lng: dbl(3.05),
    waterType: str('صالح للشرب'),
    volumeM3: int(12),
    price: int(4000),
    active: { booleanValue: true },
    createdAt: int(now),
    updatedAt: int(now),
    ...over,
  };
}

async function create(token, id, fields) {
  const r = await fetch(`${DOCS}/orders?documentId=${id}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ fields }),
  });
  return { status: r.status, body: await r.text() };
}

// `set(..., merge: true)` and `update({...})`: a masked write, like the SDK.
async function masked(token, path, fields) {
  const mask = Object.keys(fields)
    .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
    .join('&');
  const r = await fetch(`${DOCS}/${path}?${mask}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ fields }),
  });
  return { status: r.status, body: await r.text() };
}

async function get(token, path) {
  const r = await fetch(`${DOCS}/${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return { status: r.status, body: await r.text() };
}

async function poolQuery(token) {
  const r = await fetch(`${DOCS}:runQuery`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'orders' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'driverUid' },
            op: 'EQUAL',
            value: str(''),
          },
        },
      },
    }),
  });
  return { status: r.status, body: await r.text() };
}

async function del(token, path) {
  const r = await fetch(`${DOCS}/${path}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  return { status: r.status, body: await r.text() };
}

(async () => {
  const stamp = Date.now();
  const orderId = `rules-test-${stamp}`;

  // ---------------------------------------------------------------- customer
  const customer = await anon();
  const other = await anon();

  let r = await create(customer.idToken, orderId, newOrder(customer.localId));
  check('customer creates a pool order', r.status === 200, `HTTP ${r.status}`);

  r = await create(
    customer.idToken,
    `${orderId}-forged`,
    newOrder(customer.localId, { driverUid: str(customer.localId) }),
  );
  check('customer cannot pre-claim (driverUid set)', r.status === 403, `HTTP ${r.status}`);

  r = await create(
    customer.idToken,
    `${orderId}-badphone`,
    newOrder(customer.localId, { phone: str('123') }),
  );
  check('customer cannot write a bad phone', r.status === 403, `HTTP ${r.status}`);

  r = await get(customer.idToken, `orders/${orderId}`);
  check('customer reads own order', r.status === 200, `HTTP ${r.status}`);

  r = await get(other.idToken, `orders/${orderId}`);
  check('stranger cannot read that order', r.status === 403, `HTTP ${r.status}`);

  // ------------------------------------------------------------------ driver
  const driverA = await emailUser('a');
  const driverB = await emailUser('b');

  r = await masked(driverA.idToken, `drivers/${driverA.localId}`, profile());
  check('driver A creates own profile', r.status === 200, `HTTP ${r.status}`);

  r = await masked(driverB.idToken, `drivers/${driverA.localId}`, profile());
  check('driver B cannot write A profile', r.status === 403, `HTTP ${r.status}`);

  r = await masked(driverB.idToken, `drivers/${driverB.localId}`, profile());
  check('driver B creates own profile', r.status === 200, `HTTP ${r.status}`);

  r = await masked(driverA.idToken, `drivers/${driverA.localId}`, { price: int(-5) });
  check('driver cannot publish a negative price', r.status === 403, `HTTP ${r.status}`);

  r = await masked(driverA.idToken, `drivers/${driverA.localId}`, {
    active: { booleanValue: false },
  });
  check('driver can flip their own availability', r.status === 200, `HTTP ${r.status}`);

  r = await masked(driverA.idToken, `drivers/${driverA.localId}`, {
    active: { booleanValue: true },
  });
  check('driver can come back on shift', r.status === 200, `HTTP ${r.status}`);

  r = await poolQuery(driverA.idToken);
  check(
    'registered driver reads the pool (where driverUid == "")',
    r.status === 200 && r.body.includes(orderId),
    `HTTP ${r.status}`,
  );

  r = await poolQuery(other.idToken);
  check('anonymous customer cannot read the pool', r.status === 403, `HTTP ${r.status}`);

  // ------------------------------------------------------------------- claim
  const claimFields = (uid) => ({
    driverUid: str(uid),
    driverName: str('كريم بلقاسم'),
    driverPhone: str('0661234567'),
    waterType: str('صالح للشرب'),
    volumeM3: int(12),
    price: int(4000),
    status: str('accepted'),
    updatedAt: int(Date.now()),
  });

  r = await masked(driverA.idToken, `orders/${orderId}`, claimFields(driverA.localId));
  check('driver A claims the order', r.status === 200, `HTTP ${r.status}`);

  r = await masked(driverB.idToken, `orders/${orderId}`, claimFields(driverB.localId));
  check('driver B cannot steal a claimed order', r.status === 403, `HTTP ${r.status}`);

  r = await get(driverA.idToken, `orders/${orderId}`);
  check('claiming driver reads the order', r.status === 200, `HTTP ${r.status}`);

  r = await get(other.idToken, `orders/${orderId}`);
  check('stranger still cannot read it', r.status === 403, `HTTP ${r.status}`);

  r = await get(customer.idToken, `orders/${orderId}`);
  check('customer still reads their own order', r.status === 200, `HTTP ${r.status}`);

  // ---------------------------------------------------------------- progress
  r = await masked(driverA.idToken, `orders/${orderId}`, {
    nearAt: int(Date.now()),
    updatedAt: int(Date.now()),
  });
  check('driver announces "near" (nearAt)', r.status === 200, `HTTP ${r.status}`);

  r = await masked(driverA.idToken, `orders/${orderId}`, {
    status: str('sent'),
    updatedAt: int(Date.now()),
  });
  check('driver cannot rewind to sent', r.status === 403, `HTTP ${r.status}`);

  r = await masked(driverB.idToken, `orders/${orderId}`, {
    status: str('delivered'),
    updatedAt: int(Date.now()),
  });
  check('driver B cannot close driver A order', r.status === 403, `HTTP ${r.status}`);

  r = await masked(driverA.idToken, `orders/${orderId}`, {
    status: str('delivered'),
    updatedAt: int(Date.now()),
  });
  check('driver marks it delivered', r.status === 200, `HTTP ${r.status}`);

  r = await masked(driverA.idToken, `orders/${orderId}`, {
    price: int(1),
    updatedAt: int(Date.now()),
  });
  check('driver cannot rewrite the terms after claiming', r.status === 403, `HTTP ${r.status}`);

  // ---------------------------------------------------------------- cancelling
  // A separate order, because cancelling is terminal for the driver's moves.
  const cancelId = `${orderId}-cancel`;
  r = await create(customer.idToken, cancelId, newOrder(customer.localId));
  check('customer creates a second order', r.status === 200, `HTTP ${r.status}`);

  r = await masked(other.idToken, `orders/${cancelId}`, {
    status: str('cancelled'),
    updatedAt: int(Date.now()),
  });
  check('stranger cannot cancel an order', r.status === 403, `HTTP ${r.status}`);

  r = await masked(driverA.idToken, `orders/${cancelId}`, {
    status: str('cancelled'),
    updatedAt: int(Date.now()),
  });
  check('a driver cannot cancel the customer order', r.status === 403, `HTTP ${r.status}`);

  r = await masked(customer.idToken, `orders/${cancelId}`, {
    status: str('cancelled'),
    updatedAt: int(Date.now()),
  });
  check('customer cancels their own order', r.status === 200, `HTTP ${r.status}`);

  r = await masked(customer.idToken, `orders/${cancelId}`, {
    status: str('accepted'),
    updatedAt: int(Date.now()),
  });
  check('customer cannot revive a cancelled order', r.status === 403, `HTTP ${r.status}`);

  r = await del(customer.idToken, `orders/${cancelId}`);
  check('customer deletes the cancelled order', r.status === 200, `HTTP ${r.status}`);

  r = await del(driverA.idToken, `orders/${orderId}`);
  check('driver cannot delete an order', r.status === 403, `HTTP ${r.status}`);

  r = await del(other.idToken, `orders/${orderId}`);
  check('stranger cannot delete the order', r.status === 403, `HTTP ${r.status}`);

  r = await del(customer.idToken, `orders/${orderId}`);
  check('customer deletes own order', r.status === 200, `HTTP ${r.status}`);

  // ------------------------------------------------------------------ report
  const failed = results.filter((x) => !x.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  if (failed.length) console.log('FAILED: ' + failed.map((f) => f.name).join(' | '));

  // ---------------------------------------------------------------- clean up
  // A profile cannot be deleted by a client (that is a rule), so the two test
  // drivers are taken off the board instead: inactive, price 0.
  await masked(driverA.idToken, `drivers/${driverA.localId}`, {
    active: { booleanValue: false },
    price: int(0),
    updatedAt: int(Date.now()),
  });
  await masked(driverB.idToken, `drivers/${driverB.localId}`, {
    active: { booleanValue: false },
    price: int(0),
    updatedAt: int(Date.now()),
  });
  for (const user of [driverA, driverB, customer, other]) await dropUser(user);
  console.log('cleanup: orders deleted, test drivers switched off, accounts removed');
})();
