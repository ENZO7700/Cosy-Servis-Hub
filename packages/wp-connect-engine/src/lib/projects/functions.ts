import { createServerFn } from "@tanstack/react-start";
import { authMiddleware } from "@/lib/auth/middleware";
import {
  ensureDefaultProject,
  getMonthlyUsage,
  getProjectForUser,
  listProjectsForUser,
  recordUsageEvent,
  saveProjectFiles,
} from "./server";

export const listMyProjects = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    return listProjectsForUser(context.userId);
  });

export const ensureMyProject = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    return ensureDefaultProject(context.userId);
  });

export const getMyProject = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .validator((projectId: string) => projectId)
  .handler(async ({ context, data: projectId }) => {
    return getProjectForUser(context.userId, projectId);
  });

export const saveMyProject = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: {
      projectId: string;
      filesJson: string;
      activeFile?: string;
      name?: string;
      planTier?: string;
    }) => input,
  )
  .handler(async ({ context, data }) => {
    return saveProjectFiles(context.userId, data.projectId, {
      filesJson: data.filesJson,
      activeFile: data.activeFile,
      name: data.name,
      planTier: data.planTier,
    });
  });

export const getMyUsage = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    return getMonthlyUsage(context.userId);
  });

export const recordMyPromptUsage = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(
    (input: {
      projectId?: string | null;
      promptPreview?: string;
      tokensIn?: number;
      tokensOut?: number;
      model?: string;
      agent?: string;
      provider?: string;
    }) => input,
  )
  .handler(async ({ context, data }) => {
    await recordUsageEvent({
      userId: context.userId,
      projectId: data.projectId,
      promptPreview: data.promptPreview,
      tokensIn: data.tokensIn,
      tokensOut: data.tokensOut,
      model: data.model,
      agent: data.agent,
      provider: data.provider,
      kind: "prompt",
    });
    return getMonthlyUsage(context.userId);
  });
