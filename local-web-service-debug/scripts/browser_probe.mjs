#!/usr/bin/env node
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';

function usage() {
  console.log(`Usage: browser_probe.mjs --url URL [options]

Collect Playwright browser diagnostics for a local web page: console messages,
page errors, failed requests, 4xx/5xx responses, timing, redacted cookies,
storage keys, JSON report, and screenshot.

Options:
  --url URL                 URL to open. Required.
  --output-dir DIR          Artifact directory. Default: tmp directory.
  --wait-ms N               Extra wait after navigation. Default: 3000.
  --timeout-ms N            Navigation/action timeout. Default: 30000.
  --wait-until STATE        load, domcontentloaded, networkidle, or commit. Default: domcontentloaded.
  --wait-for TARGET         Wait for selector, or text=Some text.
  --click-text TEXT         Click visible text after navigation. Can be repeated.
  --storage-state FILE      Playwright storage state JSON for authenticated sessions.
  --viewport WxH            Viewport size. Default: 1280x720.
  --mobile                  Use a mobile-like viewport and user agent.
  --headed                  Run Chromium headed instead of headless.
  --ignore-https-errors     Ignore TLS certificate errors.
  --include-all-responses   Include all response statuses in JSON, not only 4xx/5xx.
  --trace                   Save a Playwright trace zip.
  --har                     Save a HAR file.
  --fail-on-issue           Exit non-zero when page errors, request failures, or 4xx/5xx responses are found.
  --help                    Show this help.

The probe does not collect request/response bodies or header values. Cookie
values are redacted; localStorage/sessionStorage values are not collected.`);
}

function parseArgs(argv) {
  const args = {
    clickText: [],
    waitMs: 3000,
    timeoutMs: 30000,
    waitUntil: 'domcontentloaded',
    viewport: '1280x720',
    mobile: false,
    headed: false,
    ignoreHTTPSErrors: false,
    includeAllResponses: false,
    trace: false,
    har: false,
    failOnIssue: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      i += 1;
      if (i >= argv.length) {
        throw new Error(`${arg} requires a value`);
      }
      return argv[i];
    };

    switch (arg) {
      case '--url':
        args.url = next();
        break;
      case '--output-dir':
        args.outputDir = next();
        break;
      case '--wait-ms':
        args.waitMs = Number(next());
        break;
      case '--timeout-ms':
        args.timeoutMs = Number(next());
        break;
      case '--wait-until':
        args.waitUntil = next();
        break;
      case '--wait-for':
        args.waitFor = next();
        break;
      case '--click-text':
        args.clickText.push(next());
        break;
      case '--storage-state':
        args.storageState = next();
        break;
      case '--viewport':
        args.viewport = next();
        break;
      case '--mobile':
        args.mobile = true;
        break;
      case '--headed':
        args.headed = true;
        break;
      case '--ignore-https-errors':
        args.ignoreHTTPSErrors = true;
        break;
      case '--include-all-responses':
        args.includeAllResponses = true;
        break;
      case '--trace':
        args.trace = true;
        break;
      case '--har':
        args.har = true;
        break;
      case '--fail-on-issue':
        args.failOnIssue = true;
        break;
      case '--help':
      case '-h':
        args.help = true;
        break;
      default:
        throw new Error(`Unknown option: ${arg}`);
    }
  }

  return args;
}

function parseViewport(raw, mobile) {
  if (mobile) {
    return { width: 390, height: 844 };
  }
  const match = /^(\d+)x(\d+)$/.exec(raw);
  if (!match) {
    throw new Error(`Invalid --viewport value: ${raw}`);
  }
  return { width: Number(match[1]), height: Number(match[2]) };
}

function timestampSlug() {
  return new Date().toISOString().replace(/[:.]/g, '-');
}

function defaultOutputDir() {
  const root = process.platform === 'darwin' ? '/private/tmp' : os.tmpdir();
  return path.join(root, `local-web-browser-probe-${timestampSlug()}`);
}

function compactError(error) {
  if (!error) {
    return null;
  }
  return {
    name: error.name,
    message: error.message,
    stack: error.stack,
  };
}

function redactCookie(cookie) {
  return {
    name: cookie.name,
    domain: cookie.domain,
    path: cookie.path,
    expires: cookie.expires,
    httpOnly: cookie.httpOnly,
    secure: cookie.secure,
    sameSite: cookie.sameSite,
    value: '[REDACTED]',
  };
}

async function loadPlaywright() {
  const requireFromCwd = createRequire(path.join(process.cwd(), 'playwright-probe.js'));
  const attempts = [
    () => requireFromCwd('playwright'),
    () => requireFromCwd('@playwright/test'),
  ];

  for (const attempt of attempts) {
    try {
      const mod = attempt();
      if (mod.chromium) {
        return mod;
      }
    } catch {
      // Try the next package name.
    }
  }

  throw new Error('Playwright is not installed in the current project. Install playwright or @playwright/test, then rerun this probe.');
}

function summarizeConsole(items) {
  return items
    .filter((item) => ['error', 'warning', 'warn'].includes(item.type))
    .slice(0, 12)
    .map((item) => `- [${item.type}] ${item.text}`);
}

function summarizeHttp(items) {
  return items.slice(0, 12).map((item) => `- ${item.status} ${item.method} ${item.url}`);
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    usage();
    process.exit(2);
  }

  if (args.help) {
    usage();
    return;
  }

  if (!args.url) {
    console.error('--url is required');
    usage();
    process.exit(2);
  }

  if (!Number.isFinite(args.waitMs) || args.waitMs < 0 || args.waitMs > 120000) {
    throw new Error(`Invalid --wait-ms value: ${args.waitMs}`);
  }
  if (!Number.isFinite(args.timeoutMs) || args.timeoutMs < 1000 || args.timeoutMs > 180000) {
    throw new Error(`Invalid --timeout-ms value: ${args.timeoutMs}`);
  }

  const allowedWaitUntil = new Set(['load', 'domcontentloaded', 'networkidle', 'commit']);
  if (!allowedWaitUntil.has(args.waitUntil)) {
    throw new Error(`Invalid --wait-until value: ${args.waitUntil}`);
  }

  const viewport = parseViewport(args.viewport, args.mobile);
  const outputDir = path.resolve(args.outputDir || defaultOutputDir());
  await fs.mkdir(outputDir, { recursive: true });

  const reportPath = path.join(outputDir, 'browser-probe-report.json');
  const screenshotPath = path.join(outputDir, 'screenshot.png');
  const tracePath = path.join(outputDir, 'trace.zip');
  const harPath = path.join(outputDir, 'network.har');

  const events = {
    console: [],
    pageErrors: [],
    requestFailed: [],
    badResponses: [],
    responses: [],
  };

  let browser;
  let context;
  let navigationError = null;
  let gotoStatus = null;
  let pageSummary = {};
  let screenshotCreated = false;

  try {
    const { chromium } = await loadPlaywright();
    browser = await chromium.launch({ headless: !args.headed });

    const contextOptions = {
      viewport,
      ignoreHTTPSErrors: args.ignoreHTTPSErrors,
    };
    if (args.mobile) {
      contextOptions.isMobile = true;
      contextOptions.hasTouch = true;
      contextOptions.userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
    }
    if (args.storageState) {
      contextOptions.storageState = path.resolve(args.storageState);
    }
    if (args.har) {
      contextOptions.recordHar = {
        path: harPath,
        content: 'omit',
      };
    }

    context = await browser.newContext(contextOptions);
    context.setDefaultTimeout(args.timeoutMs);

    if (args.trace) {
      await context.tracing.start({ screenshots: true, snapshots: true, sources: false });
    }

    const page = await context.newPage();
    page.on('console', (msg) => {
      events.console.push({
        type: msg.type(),
        text: msg.text(),
        location: msg.location(),
      });
    });
    page.on('pageerror', (error) => {
      events.pageErrors.push(compactError(error));
    });
    page.on('requestfailed', (request) => {
      events.requestFailed.push({
        method: request.method(),
        url: request.url(),
        resourceType: request.resourceType(),
        failure: request.failure(),
      });
    });
    page.on('response', (response) => {
      const item = {
        status: response.status(),
        statusText: response.statusText(),
        method: response.request().method(),
        url: response.url(),
        resourceType: response.request().resourceType(),
      };
      if (response.status() >= 400) {
        events.badResponses.push(item);
      }
      if (args.includeAllResponses) {
        events.responses.push(item);
      }
    });

    try {
      const response = await page.goto(args.url, {
        waitUntil: args.waitUntil,
        timeout: args.timeoutMs,
      });
      gotoStatus = response ? response.status() : null;
    } catch (error) {
      navigationError = compactError(error);
    }

    if (args.waitFor) {
      if (args.waitFor.startsWith('text=')) {
        await page.getByText(args.waitFor.slice('text='.length)).first().waitFor({ timeout: args.timeoutMs });
      } else {
        await page.locator(args.waitFor).first().waitFor({ timeout: args.timeoutMs });
      }
    }

    for (const text of args.clickText) {
      await page.getByText(text).first().click({ timeout: args.timeoutMs });
    }

    if (args.waitMs > 0) {
      await page.waitForTimeout(args.waitMs);
    }

    await page.screenshot({ path: screenshotPath, fullPage: true });
    screenshotCreated = true;
    const cookies = (await context.cookies()).map(redactCookie);

    pageSummary = await page.evaluate(() => {
      const nav = performance.getEntriesByType('navigation')[0];
      const resources = performance
        .getEntriesByType('resource')
        .map((entry) => ({
          name: entry.name,
          initiatorType: entry.initiatorType,
          duration: Math.round(entry.duration),
          transferSize: entry.transferSize,
        }))
        .sort((a, b) => b.duration - a.duration)
        .slice(0, 30);

      return {
        finalUrl: window.location.href,
        title: document.title,
        localStorageKeys: Object.keys(window.localStorage || {}),
        sessionStorageKeys: Object.keys(window.sessionStorage || {}),
        navigation: nav
          ? {
              type: nav.type,
              duration: Math.round(nav.duration),
              domContentLoadedEventEnd: Math.round(nav.domContentLoadedEventEnd),
              loadEventEnd: Math.round(nav.loadEventEnd),
              transferSize: nav.transferSize,
              encodedBodySize: nav.encodedBodySize,
              decodedBodySize: nav.decodedBodySize,
            }
          : null,
        slowResources: resources,
      };
    });
    pageSummary.cookies = cookies;
  } catch (error) {
    navigationError = navigationError || compactError(error);
  } finally {
    if (context) {
      if (args.trace) {
        try {
          await context.tracing.stop({ path: tracePath });
        } catch (error) {
          events.pageErrors.push(compactError(error));
        }
      }
      await context.close().catch(() => {});
    }
    if (browser) {
      await browser.close().catch(() => {});
    }
  }

  const issueCount = events.pageErrors.length + events.requestFailed.length + events.badResponses.length + (navigationError ? 1 : 0);
  const report = {
    checkedAt: new Date().toISOString(),
    input: {
      url: args.url,
      waitMs: args.waitMs,
      waitUntil: args.waitUntil,
      viewport,
      mobile: args.mobile,
    },
    navigation: {
      gotoStatus,
      error: navigationError,
    },
    page: pageSummary,
    counts: {
      console: events.console.length,
      consoleWarningsOrErrors: events.console.filter((item) => ['error', 'warning', 'warn'].includes(item.type)).length,
      pageErrors: events.pageErrors.length,
      requestFailed: events.requestFailed.length,
      badResponses: events.badResponses.length,
      responses: events.responses.length,
      issues: issueCount,
    },
    events,
    artifacts: {
      outputDir,
      reportPath,
      screenshotPath: screenshotCreated ? screenshotPath : null,
      tracePath: args.trace ? tracePath : null,
      harPath: args.har ? harPath : null,
    },
  };

  await fs.writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);

  console.log('# Browser Probe');
  console.log('');
  console.log(`- url: ${args.url}`);
  console.log(`- final_url: ${pageSummary.finalUrl || '(unknown)'}`);
  console.log(`- title: ${pageSummary.title || '(unknown)'}`);
  console.log(`- goto_status: ${gotoStatus ?? '(none)'}`);
  console.log(`- issues: ${issueCount}`);
  console.log(`- report: ${reportPath}`);
  if (screenshotCreated) {
    console.log(`- screenshot: ${screenshotPath}`);
  }
  if (args.trace) {
    console.log(`- trace: ${tracePath}`);
  }
  if (args.har) {
    console.log(`- har: ${harPath}`);
  }

  if (navigationError) {
    console.log('');
    console.log('## Navigation Error');
    console.log(`- ${navigationError.message}`);
  }

  const consoleSummary = summarizeConsole(events.console);
  if (consoleSummary.length > 0) {
    console.log('');
    console.log('## Console Warnings And Errors');
    console.log(consoleSummary.join('\n'));
  }

  if (events.pageErrors.length > 0) {
    console.log('');
    console.log('## Page Errors');
    console.log(events.pageErrors.slice(0, 8).map((item) => `- ${item.message}`).join('\n'));
  }

  if (events.requestFailed.length > 0) {
    console.log('');
    console.log('## Failed Requests');
    console.log(events.requestFailed.slice(0, 12).map((item) => `- ${item.method} ${item.url} (${item.failure?.errorText || 'failed'})`).join('\n'));
  }

  if (events.badResponses.length > 0) {
    console.log('');
    console.log('## 4xx/5xx Responses');
    console.log(summarizeHttp(events.badResponses).join('\n'));
  }

  if (args.failOnIssue && issueCount > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
