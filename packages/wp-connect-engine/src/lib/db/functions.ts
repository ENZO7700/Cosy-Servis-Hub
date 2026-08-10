/**
 * createServerFn CRUD — always authMiddleware + user_id scoping.
 */

import { createServerFn } from "@tanstack/react-start";
import { authMiddleware } from "@/lib/auth/middleware";
import {
  createApproval,
  createProject,
  deleteProject,
  deleteProjectFile,
  getProject,
  getSubscription,
  getUsageMonthly,
  insertTelemetry,
  listApprovals,
  listProjectFiles,
  listProjects,
  listTelemetry,
  listUsageEvents,
  loadProjectWorkspace,
  resolveApproval,
  updateProject,
  upsertProjectFile,
  upsertProjectFilesBulk,
} from "./domain";

// ── Workspace hydrate ──────────────────────────────────────────────────────

export const loadMyWorkspace = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .validator((projectId?: string | null) => projectId ?? null)
  .handler(async ({ context, data: projectId }) => {
    return loadProjectWorkspace(context.userId, projectId);
  });

// ── Projects ───────────────────────────────────────────────────────────────

export const listMyProjects = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => listProjects(context.userId));

export const getMyProject = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .validator((projectId: string) => projectId)
  .handler(async ({ context, data: projectId }) =>
    getProject(context.userId, projectId),
  );

export const createMyProject = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: { name: string; slug: string; planTier?: string }) => input,
  )
  .handler(async ({ context, data }) =>
    createProject(context.userId, data),
  );

export const updateMyProject = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: {
      projectId: string;
      name?: string;
      activeFile?: string;
      planTier?: string;
      slug?: string;
    }) => input,
  )
  .handler(async ({ context, data }) => {
    const { projectId, ...patch } = data;
    return updateProject(context.userId, projectId, patch);
  });

export const deleteMyProject = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator((projectId: string) => projectId)
  .handler(async ({ context, data: projectId }) =>
    deleteProject(context.userId, projectId),
  );

// ── Files ──────────────────────────────────────────────────────────────────

export const listMyProjectFiles = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .validator((projectId: string) => projectId)
  .handler(async ({ context, data: projectId }) =>
    listProjectFiles(context.userId, projectId),
  );

export const saveMyProjectFile = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: {
      projectId: string;
      path: string;
      language: string;
      content: string;
    }) => input,
  )
  .handler(async ({ context, data }) =>
    upsertProjectFile(context.userId, data.projectId, {
      path: data.path,
      language: data.language,
      content: data.content,
    }),
  );

export const saveMyProjectFiles = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: {
      projectId: string;
      files: Array<{ path: string; language: string; content: string }>;
      activeFile?: string;
    }) => input,
  )
  .handler(async ({ context, data }) =>
    upsertProjectFilesBulk(
      context.userId,
      data.projectId,
      data.files,
      data.activeFile,
    ),
  );

export const deleteMyProjectFile = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator((input: { projectId: string; path: string }) => input)
  .handler(async ({ context, data }) =>
    deleteProjectFile(context.userId, data.projectId, data.path),
  );

// ── Approvals ──────────────────────────────────────────────────────────────

export const createMyApproval = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: {
      projectId?: string | null;
      title: string;
      description: string;
      affectedFiles: string[];
      originalCode: string;
      modifiedCode: string;
      language: string;
      previewHtml?: string;
    }) => input,
  )
  .handler(async ({ context, data }) =>
    createApproval(context.userId, data),
  );

export const listMyApprovals = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .validator(
    (input?: { projectId?: string; status?: string; limit?: number }) =>
      input ?? {},
  )
  .handler(async ({ context, data }) =>
    listApprovals(context.userId, data),
  );

export const resolveMyApproval = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: {
      approvalId: string;
      status: "approved" | "rejected";
      rejectionReason?: string | null;
    }) => input,
  )
  .handler(async ({ context, data }) =>
    resolveApproval(context.userId, data.approvalId, {
      status: data.status,
      rejectionReason: data.rejectionReason,
    }),
  );

// ── Telemetry ──────────────────────────────────────────────────────────────

export const recordMyTelemetry = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: {
      projectId?: string | null;
      prompt: string;
      status: "APPROVED" | "REJECTED";
      rejectionReason?: string | null;
      agentType: string;
      latencyMs: number;
    }) => input,
  )
  .handler(async ({ context, data }) =>
    insertTelemetry(context.userId, data),
  );

export const listMyTelemetry = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .validator((limit?: number) => limit ?? 50)
  .handler(async ({ context, data: limit }) =>
    listTelemetry(context.userId, { limit }),
  );

// ── Subscriptions + usage ──────────────────────────────────────────────────

export const getMySubscription = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => getSubscription(context.userId));

export const getMyUsageMonthly = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => getUsageMonthly(context.userId));

export const listMyUsageEvents = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .validator((limit?: number) => limit ?? 50)
  .handler(async ({ context, data: limit }) =>
    listUsageEvents(context.userId, { limit }),
  );
