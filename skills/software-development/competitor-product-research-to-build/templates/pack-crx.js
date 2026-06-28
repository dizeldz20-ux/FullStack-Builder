// pack-crx.js — package a Chrome/Edge MV3 extension as a CRX3 file
// Run on the Hermes host (or any machine with Node + OpenSSL).
//
// Usage:
//   node pack-crx.js <ext_dir> <private_key.pem> <output.crx>
//
// Output: a CRX3 file signed with the private key. The corresponding
// extension ID is derived from the SHA-256 of the public key — see
// the script's extIdFromPubKey() helper at the bottom.

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const extDir = process.argv[2];
const privKeyPath = process.argv[3];
const outCrx = process.argv[4];

if (!extDir || !privKeyPath || !outCrx) {
  console.error("Usage: node pack-crx.js <ext_dir> <priv_key.pem> <output.crx>");
  process.exit(1);
}

console.log("Packaging:", extDir);

// 1. Load the private key
const privKeyPem = fs.readFileSync(privKeyPath, "utf8");
const privKeyObj = crypto.createPrivateKey(privKeyPem);

// 2. Export the public key as DER (SPKI) — this is what goes into both
//    the CRX header AND is hashed to compute the extension ID
const pubKeyDer = crypto.createPublicKey(privKeyObj).export({ type: "spki", format: "der" });

// 3. Walk the extension dir to build the file list (relative paths)
const files = [];
function walk(dir, prefix = "") {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) walk(path.join(dir, entry.name), rel);
    else files.push({ rel, abs: path.join(dir, entry.name) });
  }
}
walk(extDir);

// 4. Build a stored (no-compression) ZIP. CRC-32 + DOS headers. Keeping
//    it dependency-free so this works on any Node.
function crc32(buf) {
  const table = [];
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  let crc = 0xffffffff;
  for (const b of buf) crc = (crc >>> 8) ^ table[(crc ^ b) & 0xff];
  return (crc ^ 0xffffffff) >>> 0;
}
function dosTime(d = new Date()) {
  const t = ((d.getHours() & 0x1f) << 11) | ((d.getMinutes() & 0x3f) << 5) | ((d.getSeconds() / 2) & 0x1f);
  const dd = (((d.getFullYear() - 1980) & 0x7f) << 9) | (((d.getMonth() + 1) & 0xf) << 5) | (d.getDate() & 0x1f);
  return { time: t, date: dd };
}
function buildZip(files) {
  const local = [];
  const central = [];
  let offset = 0;
  for (const f of files) {
    const data = fs.readFileSync(f.abs);
    const nameBuf = Buffer.from(f.rel, "utf8");
    const { time, date } = dosTime();
    const crc = crc32(data);
    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0); // local file header sig
    lh.writeUInt16LE(20, 4);          // version needed
    lh.writeUInt16LE(0, 6);           // flags
    lh.writeUInt16LE(0, 8);           // method = stored
    lh.writeUInt16LE(time, 10);
    lh.writeUInt16LE(date, 12);
    lh.writeUInt32LE(crc, 14);
    lh.writeUInt32LE(data.length, 18); // comp size
    lh.writeUInt32LE(data.length, 22); // uncomp size
    lh.writeUInt16LE(nameBuf.length, 26);
    lh.writeUInt16LE(0, 28);          // extra
    local.push(lh, nameBuf, data);
    const ch = Buffer.alloc(46);
    ch.writeUInt32LE(0x02014b50, 0); // central dir sig
    ch.writeUInt16LE(20, 4);
    ch.writeUInt16LE(20, 6);
    ch.writeUInt16LE(0, 8);
    ch.writeUInt16LE(0, 10);
    ch.writeUInt16LE(time, 12);
    ch.writeUInt16LE(date, 14);
    ch.writeUInt32LE(crc, 16);
    ch.writeUInt32LE(data.length, 20);
    ch.writeUInt32LE(data.length, 24);
    ch.writeUInt16LE(nameBuf.length, 28);
    ch.writeUInt16LE(0, 30);
    ch.writeUInt16LE(0, 32);
    ch.writeUInt16LE(0, 34);
    ch.writeUInt32LE(0, 38);
    ch.writeUInt32LE(offset, 42);
    central.push(ch, nameBuf);
    offset += lh.length + nameBuf.length + data.length;
  }
  const localPart = Buffer.concat(local);
  const centralPart = Buffer.concat(central);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(0, 4);
  eocd.writeUInt16LE(0, 6);
  eocd.writeUInt16LE(files.length, 8);
  eocd.writeUInt16LE(files.length, 10);
  eocd.writeUInt32LE(centralPart.length, 12);
  eocd.writeUInt32LE(localPart.length, 16);
  eocd.writeUInt16LE(0, 20);
  return Buffer.concat([localPart, centralPart, eocd]);
}

const zipBuf = buildZip(files);
console.log("ZIP size:", zipBuf.length);

// 5. Protobuf helpers (minimal — only what CRX3 needs)
function pbVarint(n) {
  const out = [];
  while (n > 0x7f) { out.push((n & 0x7f) | 0x80); n >>>= 7; }
  out.push(n & 0x7f);
  return Buffer.from(out);
}
function pbFieldVarint(fieldNum, value) {
  return Buffer.concat([pbVarint((fieldNum << 3) | 0), pbVarint(value)]);
}
function pbFieldBytes(fieldNum, buf) {
  return Buffer.concat([pbVarint((fieldNum << 3) | 2), pbVarint(buf.length), buf]);
}

// 6. The signed_header_data is the protobuf of {4: 2} (CRX3 file format version 2).
//    This is what we sign with the private key. The "Cr24" magic is NOT signed.
const signedHeader = pbFieldVarint(4, 2);

const sign = crypto.createSign("SHA256");
sign.update(signedHeader);
sign.end();
const signature = sign.sign(privKeyObj); // PKCS#1 v1.5 over SHA-256

// 7. The signed_data protobuf carries: SHA-256 of pubkey, pubkey, signature, crx_version
const sha256OfPub = crypto.createHash("sha256").update(pubKeyDer).digest();
const signedData = Buffer.concat([
  pbFieldBytes(1, sha256OfPub),   // sha256_prehash
  pbFieldBytes(2, pubKeyDer),     // public_key (SPKI DER)
  pbFieldBytes(3, signature),     // signature
  pbFieldVarint(4, 2),            // crx_version
]);

// 8. Assemble the CRX: magic | version | header_len | signed_data | zip
const crx = Buffer.concat([
  Buffer.from("Cr24"),
  pbVarint(3),                          // CRX format version (outer)
  pbVarint(signedData.length),          // signed_data length
  signedData,
  zipBuf,
]);

fs.writeFileSync(outCrx, crx);
console.log("CRX written to:", outCrx, "(", crx.length, "bytes )");
console.log("Extension ID will be:", extIdFromPubKey(pubKeyDer));

// 9. Compute the Chrome/Edge extension ID from the public key.
//    Per the spec: first 16 bytes of SHA-256(public_key), each byte
//    mapped as two chars: 'a' + (byte >> 4) and 'a' + (byte & 0xf).
function extIdFromPubKey(pubKeyDerBuf) {
  const h = crypto.createHash("sha256").update(pubKeyDerBuf).digest().subarray(0, 16);
  let out = "";
  for (const b of h) {
    out += String.fromCharCode("a".charCodeAt(0) + (b >> 4));
    out += String.fromCharCode("a".charCodeAt(0) + (b & 0xf));
  }
  return out;
}
