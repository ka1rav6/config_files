import type { VisitRecord } from "../types";
import { saveVisit, deleteVisitsOlderThan, getSettings } from "../lib/db";
import { classifyVisit, extractDomain } from "../lib/classify";
import { embedText } from "../lib/embeddings";
import { assignToSession, pruneStaleLiveSessions } from "../lib/sessions";

// ---- Visit capture ----

chrome.history.onVisited.addListener(async (historyItem) => {
  if (!historyItem.url) return;
  await recordVisit(historyItem.url, historyItem.title ?? "", null);
});

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (changeInfo.status !== "complete" || !tab.url) return;
  await recordVisit(tab.url, tab.title ?? "", tabId);
});

async function recordVisit(url: string, title: string, tabId: number | null) {
  if (!isTrackableUrl(url)) return;

  const visit: VisitRecord = {
    id: crypto.randomUUID(),
    url,
    title,
    domain: extractDomain(url),
    visitTime: Date.now(),
    tabId,
    category: classifyVisit(url),
    embedding: null,
    sessionId: null,
  };

  // Embed asynchronously so capture never blocks on the model.
  try {
    visit.embedding = await embedText(`${title} ${url}`);
  } catch (err) {
    console.warn("WayFinder: embedding failed, continuing without it", err);
  }

  assignToSession(visit);
  await saveVisit(visit);
}

function isTrackableUrl(url: string): boolean {
  return /^https?:\/\//.test(url);
}

// ---- Retention cleanup (free tier: 90 days) ----

chrome.alarms.create("wayfinder-cleanup", { periodInMinutes: 60 * 24 });

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name !== "wayfinder-cleanup") return;

  const settings = await getSettings();
  if (settings.historyRetentionDays > 0) {
    const cutoff = Date.now() - settings.historyRetentionDays * 24 * 60 * 60 * 1000;
    const deleted = await deleteVisitsOlderThan(cutoff);
    console.log(`WayFinder: pruned ${deleted} visits past retention window`);
  }

  pruneStaleLiveSessions(Date.now());
});

// ---- Side panel wiring ----

chrome.action.onClicked.addListener((tab) => {
  if (tab.windowId !== undefined) {
    chrome.sidePanel.open({ windowId: tab.windowId });
  }
});

// ---- Message bridge for side panel <-> background ----

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === "PING") {
    sendResponse({ ok: true });
  }
  // Additional message handlers (search, session fetch, etc.) get added
  // here as the side panel UI grows.
});

console.log("WayFinder background service worker started");
