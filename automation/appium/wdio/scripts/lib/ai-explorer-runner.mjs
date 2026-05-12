import { JsonlExplorerClient } from "./ai-explorer-jsonl-client.mjs";
import { evaluateExplorerAction } from "./ai-explorer-guardrails.mjs";
import { publicConfig, readAiExplorerConfig } from "./ai-explorer-config.mjs";
import { requestExplorerDecision } from "./ai-explorer-model.mjs";
import {
  addFinding,
  addStep,
  createExplorerReport,
  deriveReportStatus,
  writeExplorerReports
} from "./ai-explorer-report.mjs";
import { getProjectPaths } from "./paths.mjs";

function compactEvent(event) {
  const result = event?.result ?? event;
  if (!result || typeof result !== "object") {
    return result;
  }

  return {
    activeApp: result.activeApp,
    appIdentity: result.appIdentity,
    appState: result.appState,
    labels: Array.isArray(result.labels) ? result.labels.slice(0, 20) : undefined,
    target: result.target,
    bundleId: result.bundleId
  };
}

function compactInspect(event) {
  const result = event?.result ?? event;
  if (!result || typeof result !== "object") {
    return result;
  }

  return {
    artifacts: result.artifacts,
    elements: Array.isArray(result.elements) ? result.elements.slice(0, 25) : undefined,
    labels: Array.isArray(result.labels) ? result.labels.slice(0, 25) : undefined,
    tree: Array.isArray(result.tree) ? result.tree.slice(0, 25) : undefined
  };
}

function stepSignature(action) {
  return `${action.command}:${JSON.stringify(action.args ?? {})}`;
}

function repetitionLimit(action) {
  if (action.command === "ui.tap" || action.command === "ui.exists") {
    return 1;
  }
  if (action.command === "ui.inspect") {
    return 2;
  }
  return 3;
}

function labelSignature(summary) {
  const labels = summary?.labels ?? [];
  return Array.isArray(labels) ? labels.slice(0, 8).join("|") : "";
}

function recordAction(state, action) {
  if (typeof action.args?.selector === "string") {
    state.triedSelectors.set(
      action.args.selector,
      (state.triedSelectors.get(action.args.selector) ?? 0) + 1
    );
  }
}

function compactMap(map, limit = 12) {
  return [...map.entries()]
    .slice(-limit)
    .map(([value, count]) => ({ value, count }));
}

function createFakeDecisionProvider() {
  const decisions = [
    {
      command: "ui.inspect",
      args: { compact: true, interactiveOnly: true, limit: 30, visibleOnly: true },
      reason: "Inspect interactive controls after the static smoke completed.",
      confidence: 1
    },
    {
      command: "ui.scroll",
      args: { direction: "down" },
      reason: "Reveal lower home content without changing app state.",
      confidence: 1
    },
    {
      command: "ui.inspect",
      args: { compact: true, interactiveOnly: true, limit: 30, visibleOnly: true },
      reason: "Inspect the lower visible surface after scrolling.",
      confidence: 1
    },
    {
      command: "ui.scroll",
      args: { direction: "up" },
      reason: "Return toward the original visible surface.",
      confidence: 1
    },
    {
      command: "ui.summary",
      args: { limit: 25, visibleOnly: true },
      reason: "Confirm the app is still responsive.",
      confidence: 1
    },
    {
      command: "finish",
      args: {},
      reason: "Fake model completed its deterministic smoke exploration.",
      confidence: 1
    }
  ];
  let index = 0;
  return async () => decisions[Math.min(index++, decisions.length - 1)];
}

async function executeExplorerCommand(client, report, command, args, reason) {
  report.log?.(`AI explorer command: ${command}${reason ? ` - ${reason}` : ""}`);
  addStep(report, {
    kind: "command",
    command,
    args,
    reason
  });

  const event = await client.command(command, args);
  report.log?.(`AI explorer result: ${command}`);
  addStep(report, {
    kind: "result",
    command,
    result: compactEvent(event)
  });
  return event;
}

async function observeSummary(client, report, reason = "Observe current UI.") {
  const event = await executeExplorerCommand(
    client,
    report,
    "ui.summary",
    { limit: 25, visibleOnly: true },
    reason
  );
  return event.result;
}

async function observeInspect(client, report, reason = "Inspect current UI.") {
  const event = await executeExplorerCommand(
    client,
    report,
    "ui.inspect",
    {
      compact: true,
      elements: true,
      interactiveOnly: true,
      labels: true,
      limit: 35,
      tree: true,
      visibleOnly: true
    },
    reason
  );
  return event.result;
}

function evaluateSummary(report, summary, state) {
  const labels = Array.isArray(summary?.labels) ? summary.labels : [];
  const foreground = summary?.appState?.code === 4;

  if (!foreground) {
    addFinding(report, "critical", "App is not in foreground during AI exploration.", {
      appState: summary?.appState,
      target: summary?.target,
      bundleId: summary?.bundleId
    });
  }

  if (labels.length === 0) {
    addFinding(report, "critical", "Visible UI summary has no readable labels.", {
      appIdentity: summary?.appIdentity,
      target: summary?.target
    });
  }

  const signature = labelSignature(summary);
  if (signature) {
    state.labelSignatures.set(signature, (state.labelSignatures.get(signature) ?? 0) + 1);
    const repeatCount = state.labelSignatures.get(signature);
    if (repeatCount >= 4 && !state.inCoverageIntervention) {
      state.needsCoverageIntervention =
        state.needsCoverageIntervention ??
        "Visible UI has repeated several times; force a scroll/back coverage action.";
    }
    if (repeatCount >= 6) {
      addFinding(report, "warning", "Explorer appears to be revisiting the same visible UI repeatedly.", {
        labels: labels.slice(0, 8)
      });
    }
  }

  const loadingLabels = labels.filter((label) =>
    /\b(loading|please wait|initializing|starting)\b/i.test(String(label))
  );
  if (loadingLabels.length > 0) {
    state.loadingObservations += 1;
    if (state.loadingObservations >= 3) {
      addFinding(report, "warning", "Loading-style text persisted across several observations.", {
        labels: loadingLabels
      });
    }
  } else {
    state.loadingObservations = 0;
  }
}

async function runCoverageIntervention(client, report, state, reason) {
  const interventions = [
    {
      command: "ui.scroll",
      args: { direction: "down" },
      reason: "Coverage intervention: scroll down to reveal lower content."
    },
    {
      command: "ui.scroll",
      args: { direction: "up" },
      reason: "Coverage intervention: scroll up to verify the upper content."
    },
    {
      command: "ui.back",
      args: {},
      reason: "Coverage intervention: go back to escape a repeated screen."
    },
    {
      command: "ui.scroll",
      args: { direction: "down" },
      reason: "Coverage intervention: scroll after navigation to inspect another section."
    }
  ];
  const intervention = interventions[state.coverageInterventions % interventions.length];
  state.coverageInterventions += 1;
  state.inCoverageIntervention = true;

  report.log?.(`AI explorer coverage intervention: ${reason}`);
  addStep(report, {
    kind: "coverage",
    command: intervention.command,
    args: intervention.args,
    reason
  });

  try {
    await executeExplorerCommand(
      client,
      report,
      intervention.command,
      intervention.args,
      intervention.reason
    );
  } catch (error) {
    addFinding(report, "warning", `Coverage intervention failed: ${intervention.command}`, {
      args: intervention.args,
      error: error instanceof Error ? error.message : String(error)
    });
  }

  state.summary = await observeSummary(client, report, "Observe after coverage intervention.");
  evaluateSummary(report, state.summary, state);
  state.inspect = await observeInspect(client, report, "Inspect after coverage intervention.");
  state.inCoverageIntervention = false;
  state.needsCoverageIntervention = undefined;
}

async function runInitialCoverageProbe(client, report, state) {
  await runCoverageIntervention(
    client,
    report,
    state,
    "Initial coverage probe before model-led exploration."
  );
  await runCoverageIntervention(
    client,
    report,
    state,
    "Initial coverage probe return pass before model-led exploration."
  );
}

async function recoverToApp(client, report) {
  try {
    await executeExplorerCommand(
      client,
      report,
      "app.activate",
      {},
      "Recover by activating the configured app."
    );
    return true;
  } catch (error) {
    addFinding(report, "critical", "Failed to reactivate app after explorer detected bad foreground state.", {
      error: error instanceof Error ? error.message : String(error)
    });
    return false;
  }
}

async function runFallbackProbe(client, report, state) {
  addFinding(report, "warning", "Model decision unavailable; ran deterministic fallback probe.", {});
  state.inspect = await observeInspect(client, report, "Fallback probe: inspect visible controls.");
  await executeExplorerCommand(
    client,
    report,
    "ui.scroll",
    { direction: "down" },
    "Fallback probe: scroll down."
  );
  state.summary = await observeSummary(client, report, "Fallback probe: observe after scrolling.");
  evaluateSummary(report, state.summary, state);
  await executeExplorerCommand(
    client,
    report,
    "ui.scroll",
    { direction: "up" },
    "Fallback probe: scroll up."
  );
  state.summary = await observeSummary(client, report, "Fallback probe: final observation.");
  evaluateSummary(report, state.summary, state);
}

function shouldForceMoreExploration(action, stepIndex, minSteps) {
  return action.command === "finish" && stepIndex < minSteps;
}

export async function runAiExplorer(options = {}) {
  const env = options.env ?? process.env;
  const paths = getProjectPaths(env);
  const outputDir = options.outputDir ?? paths.outputDir;
  const log = options.log ?? console.error;
  const config = options.config ?? readAiExplorerConfig(env);
  const startedAt = new Date();
  const report = createExplorerReport({
    config: publicConfig(config),
    deviceName: env.IOS_DEVICE_NAME,
    startedAt: startedAt.toISOString(),
    udid: env.IOS_UDID
  });
  report.log = (message) => log(message);
  const client =
    options.client ??
    new JsonlExplorerClient({
      cwd: paths.wdioRoot,
      env,
      log
    });
  const state = {
    actionSignatures: new Map(),
    coverageInterventions: 0,
    findings: report.findings,
    inCoverageIntervention: false,
    inspect: undefined,
    labelSignatures: new Map(),
    loadingObservations: 0,
    needsCoverageIntervention: undefined,
    summary: undefined,
    triedSelectors: new Map()
  };
  const decisionProvider =
    options.decisionProvider ??
    (config.fakeModel
      ? createFakeDecisionProvider()
      : async (decisionState) => {
          const response = await requestExplorerDecision({
            config,
            fetchFn: options.fetchFn,
            state: decisionState
          });
          log(`AI explorer model decision: ${response.rawContent.trim().slice(0, 500)}`);
          addStep(report, {
            kind: "model",
            command: "decision",
            reason: response.rawContent,
            usage: response.usage
          });
          return response.decision;
        });

  try {
    log(
      `AI explorer starting with model ${config.model} at ${config.baseUrl}; budget ${config.stepLimit} steps / ${Math.round(config.timeoutMs / 1000)}s.`
    );
    client.start();

    const statusEvent = await executeExplorerCommand(
      client,
      report,
      "session.status",
      {},
      "Confirm explorer session."
    );
    report.deviceName = statusEvent.result?.deviceName ?? report.deviceName;
    report.udid = statusEvent.result?.udid ?? report.udid;

    if (statusEvent.result?.appState?.code === 4) {
      addStep(report, {
        kind: "activation-skip",
        command: "app.activate",
        reason:
          "Skipped activation because session.status already reported the configured app in foreground."
      });
      log(
        "AI explorer skipped app.activate because the configured app is already foreground."
      );
    } else {
      await executeExplorerCommand(
        client,
        report,
        "app.activate",
        {},
        "Bring the already-onboarded app to foreground."
      );
    }
    state.summary = await observeSummary(client, report, "Initial post-smoke UI summary.");
    evaluateSummary(report, state.summary, state);
    state.inspect = await observeInspect(client, report, "Initial post-smoke UI inspection.");
    await runInitialCoverageProbe(client, report, state);

    const deadline = Date.now() + config.timeoutMs;
    for (let stepIndex = 0; stepIndex < config.stepLimit && Date.now() < deadline; stepIndex += 1) {
      let decision;
      try {
        log(`AI explorer asking model for step ${stepIndex + 1}/${config.stepLimit}.`);
        decision = await decisionProvider({
          findings: report.findings.map(({ severity, message }) => ({ severity, message })),
          history: report.steps.slice(-12).map((step) => ({
            args: step.args,
            kind: step.kind,
            command: step.command,
            reason: step.reason
          })),
          inspect: compactInspect({ result: state.inspect }),
          minSteps: config.minSteps,
          stepIndex,
          stepLimit: config.stepLimit,
          summary: compactEvent({ result: state.summary }),
          triedSelectors: compactMap(state.triedSelectors),
          usedActions: compactMap(state.actionSignatures)
        });
      } catch (error) {
        addFinding(report, "warning", "Model decision request failed.", {
          error: error instanceof Error ? error.message : String(error)
        });
        await runFallbackProbe(client, report, state);
        report.completed = true;
        break;
      }

      const guard = evaluateExplorerAction(decision, {
        sessionBundleId: env.APP_BUNDLE_ID
      });
      if (!guard.allowed) {
        log(`AI explorer guardrail denied ${guard.action.command}: ${guard.reason}`);
        addStep(report, {
          kind: "guardrail",
          command: guard.action.command,
          args: guard.action.args,
          reason: guard.reason
        });
        continue;
      }

      const { action } = guard;
      if (shouldForceMoreExploration(action, stepIndex, config.minSteps)) {
        log("AI explorer model asked to finish early; collecting one more inspection.");
        state.inspect = await observeInspect(
          client,
          report,
          "Model wanted to finish before the minimum useful step count; inspect instead."
        );
        continue;
      }

      if (action.command === "finish") {
        log(`AI explorer finish requested: ${action.reason}`);
        addStep(report, {
          kind: "finish",
          command: "finish",
          reason: action.reason
        });
        report.completed = true;
        break;
      }

      const signature = stepSignature(action);
      state.actionSignatures.set(signature, (state.actionSignatures.get(signature) ?? 0) + 1);
      const actionRepeatCount = state.actionSignatures.get(signature);
      if (actionRepeatCount > repetitionLimit(action)) {
        log(`AI explorer skipped repeated action: ${signature}`);
        addStep(report, {
          kind: "guardrail",
          command: action.command,
          args: action.args,
          reason: "Skipped repeated action to avoid a loop."
        });
        await runCoverageIntervention(
          client,
          report,
          state,
          `Repeated action skipped: ${signature}`
        );
        continue;
      }
      recordAction(state, action);

      let event;
      try {
        event = await executeExplorerCommand(
          client,
          report,
          action.command,
          action.args,
          action.reason
        );
      } catch (error) {
        addFinding(report, "warning", `Explorer command failed: ${action.command}`, {
          args: action.args,
          error: error instanceof Error ? error.message : String(error),
          reason: action.reason
        });
        state.summary = await observeSummary(client, report, "Observe after command failure.");
        continue;
      }

      let summaryUpdated = false;
      if (action.command === "ui.inspect") {
        state.inspect = event.result;
      } else if (action.command === "ui.summary") {
        state.summary = event.result;
        summaryUpdated = true;
      } else {
        state.summary = await observeSummary(client, report, "Observe after model action.");
        summaryUpdated = true;
      }

      if (summaryUpdated) {
        evaluateSummary(report, state.summary, state);
      }
      if (state.summary?.appState?.code !== 4) {
        await recoverToApp(client, report);
        state.summary = await observeSummary(client, report, "Observe after app recovery.");
        evaluateSummary(report, state.summary, state);
      }

      if (state.needsCoverageIntervention) {
        await runCoverageIntervention(
          client,
          report,
          state,
          state.needsCoverageIntervention
        );
        continue;
      }

      if (stepIndex % 4 === 3) {
        state.inspect = await observeInspect(client, report, "Periodic inspection after exploration steps.");
      }
    }

    if (!report.completed) {
      report.completed = true;
      addStep(report, {
        kind: "finish",
        command: "budget",
        reason: "Explorer stopped at configured step or time budget."
      });
    }
  } catch (error) {
    log(`AI explorer infrastructure failure: ${error instanceof Error ? error.message : String(error)}`);
    report.infrastructureFailure = true;
    addFinding(report, "critical", "AI explorer infrastructure failed before completing.", {
      error: error instanceof Error ? error.message : String(error)
    });
  } finally {
    await client.shutdown().catch((error) => {
      addFinding(report, "warning", "Failed to shut down explorer session cleanly.", {
        error: error instanceof Error ? error.message : String(error)
      });
    });

    report.durationMs = Date.now() - startedAt.getTime();
    report.summary = `AI explorer finished with status ${deriveReportStatus(report)} after ${report.steps.length} recorded steps.`;
    report.artifacts = await writeExplorerReports(report, outputDir);
    delete report.log;
    log(`AI explorer report written: ${report.artifacts.markdownPath}`);
  }

  return report;
}
