const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function randomBlock(n = 4) {
  let s = '';
  for (let i = 0; i < n; i++) s += CHARS[Math.floor(Math.random() * CHARS.length)];
  return s;
}

function generateKey() {
  return `${randomBlock()}-${randomBlock()}-${randomBlock()}`;
}

module.exports = { generateKey };
