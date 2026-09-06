import { performance } from 'node:perf_hooks';
import { createRequire, syncBuiltinESMExports } from 'node:module';
import childProcess from 'node:child_process';

const root = process.env.MCP_ROOT ?? '/usr/lib/node_modules/firefox-devtools-mcp';
const require = createRequire(`${root}/package.json`);
const started = performance.now();
const report = (name, start) => {
  console.log(`${name}: ${(performance.now() - start).toFixed(0)} ms`);
};

const spawnSync = childProcess.spawnSync;
childProcess.spawnSync = function (command, ...args) {
  const start = performance.now();
  try {
    return spawnSync.call(this, command, ...args);
  } finally {
    report(`spawnSync ${command.split('/').pop()}`, start);
  }
};
syncBuiltinESMExports();

function timeAsync(target, method, label) {
  const original = target[method];
  target[method] = async function (...args) {
    const start = performance.now();
    try {
      return await original.apply(this, args);
    } finally {
      report(label, start);
    }
  };
}

const io = require('selenium-webdriver/io');
const { Zip } = require('selenium-webdriver/io/zip');
const { Builder } = require('selenium-webdriver');
timeAsync(io, 'copyDir', 'profile copy');
timeAsync(Zip.prototype, 'addDir', 'profile archive input');
timeAsync(Zip.prototype, 'toBuffer', 'profile compression');
timeAsync(Builder.prototype, 'build', 'WebDriver build');

const { FirefoxDevTools } = await import(`${root}/dist/index.js`);
report('module import', started);
const browser = new FirefoxDevTools({
  headless: process.env.BENCH_HEADLESS !== '0',
  firefoxPath: process.env.BENCH_FIREFOX ?? '/usr/local/bin/firefox-hardened',
  profilePath: process.env.BENCH_PROFILE,
  instanceId: 'startup-benchmark',
  startUrl: 'about:blank',
});
try {
  const start = performance.now();
  await browser.connect();
  report('Firefox ready', start);
  const navigation = performance.now();
  await browser.navigate('data:text/html,<title>Startup benchmark</title><button>Ready</button>');
  await browser.takeSnapshot();
  report('navigation + snapshot', navigation);
} finally {
  const close = performance.now();
  await browser.close();
  report('Firefox close', close);
  report('total', started);
}
