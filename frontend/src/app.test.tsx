import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  loadProjects,
  loadTasks,
  ProjectButtons,
  TaskList,
  updateTaskStatus,
} from "./app.js";

describe("project tracker UI flows", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("renders retrieved projects and opens their task list", async () => {
    const project = { id: "project-1", name: "Roadmap" };
    const task = { id: "task-1", title: "Ship P2", status: "todo" };
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ projects: [project] })))
      .mockResolvedValueOnce(new Response(JSON.stringify({ tasks: [task] })));
    vi.stubGlobal("fetch", fetchMock);
    const projects = await loadProjects();
    expect(
      renderToStaticMarkup(
        <ProjectButtons projects={projects} onOpen={() => undefined} />,
      ),
    ).toContain("Roadmap");
    const tasks = await loadTasks(project);
    expect(
      renderToStaticMarkup(<TaskList tasks={tasks} onStatus={() => undefined} />),
    ).toContain("Ship P2");
    expect(fetchMock).toHaveBeenLastCalledWith(
      "/api/projects/project-1/tasks",
      expect.any(Object),
    );
  });

  it("patches task status then refreshes task state", async () => {
    const project = { id: "project-1", name: "Roadmap" };
    const updated = { id: "task-1", title: "Ship P2", status: "done" };
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ task: updated })))
      .mockResolvedValueOnce(new Response(JSON.stringify({ tasks: [updated] })));
    vi.stubGlobal("fetch", fetchMock);
    await expect(updateTaskStatus(project, updated.id, "done")).resolves.toEqual([
      updated,
    ]);
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "/api/projects/project-1/tasks/task-1",
      expect.objectContaining({
        method: "PATCH",
        body: JSON.stringify({ status: "done" }),
      }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "/api/projects/project-1/tasks",
      expect.any(Object),
    );
  });
});
