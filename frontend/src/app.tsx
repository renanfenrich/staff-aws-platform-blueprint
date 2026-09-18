import { useState } from "react";
import { api } from "./api.js";

export type Project = { id: string; name: string };
export type Task = { id: string; title: string; status: string };

export async function loadProjects(): Promise<Project[]> {
  return (await api<{ projects: Project[] }>("/api/projects")).projects;
}
export async function loadTasks(project: Project): Promise<Task[]> {
  return (await api<{ tasks: Task[] }>(`/api/projects/${project.id}/tasks`)).tasks;
}
export async function updateTaskStatus(
  project: Project,
  taskId: string,
  status: string,
): Promise<Task[]> {
  await api(`/api/projects/${project.id}/tasks/${taskId}`, {
    method: "PATCH",
    body: JSON.stringify({ status }),
  });
  return loadTasks(project);
}
export function ProjectButtons({
  projects,
  onOpen,
}: {
  projects: Project[];
  onOpen: (project: Project) => void;
}) {
  return projects.map((project) => (
    <button type="button" key={project.id} onClick={() => onOpen(project)}>
      {project.name}
    </button>
  ));
}
export function TaskList({
  tasks,
  onStatus,
}: {
  tasks: Task[];
  onStatus: (taskId: string, status: string) => void;
}) {
  return tasks.map((task) => (
    <p key={task.id}>
      {task.title}{" "}
      <select
        value={task.status}
        onChange={(event) => onStatus(task.id, event.target.value)}
      >
        <option>todo</option>
        <option>in_progress</option>
        <option>done</option>
      </select>
    </p>
  ));
}
export function App() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [projects, setProjects] = useState<Project[]>([]);
  const [selected, setSelected] = useState<Project>();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [name, setName] = useState("");
  const [title, setTitle] = useState("");
  const [error, setError] = useState("");
  const load = () =>
    loadProjects()
      .then(setProjects)
      .catch(() => undefined);
  async function auth(register: boolean) {
    try {
      await api(`/api/auth/${register ? "register" : "login"}`, {
        method: "POST",
        body: JSON.stringify({ email, password }),
      });
      setError("");
      await load();
    } catch {
      setError("Authentication failed");
    }
  }
  async function open(project: Project) {
    setSelected(project);
    setTasks(await loadTasks(project));
  }
  return (
    <main>
      <h1>Project tracker</h1>
      <p>{error}</p>
      <input placeholder="email" onChange={(event) => setEmail(event.target.value)} />
      <input
        placeholder="password"
        type="password"
        onChange={(event) => setPassword(event.target.value)}
      />
      <button type="button" onClick={() => auth(true)}>
        Register
      </button>
      <button type="button" onClick={() => auth(false)}>
        Login
      </button>
      <button
        type="button"
        onClick={() =>
          api("/api/auth/logout", { method: "POST" }).then(() => {
            setProjects([]);
            setSelected(undefined);
          })
        }
      >
        Logout
      </button>
      <h2>Projects</h2>
      <input
        placeholder="project name"
        value={name}
        onChange={(event) => setName(event.target.value)}
      />
      <button
        type="button"
        onClick={async () => {
          await api("/api/projects", {
            method: "POST",
            body: JSON.stringify({ name }),
          });
          setName("");
          await load();
        }}
      >
        Create
      </button>
      <ProjectButtons projects={projects} onOpen={open} />
      {selected && (
        <section>
          <h2>{selected.name}</h2>
          <input
            placeholder="task title"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
          />
          <button
            type="button"
            onClick={async () => {
              await api(`/api/projects/${selected.id}/tasks`, {
                method: "POST",
                body: JSON.stringify({ title }),
              });
              await open(selected);
            }}
          >
            Add task
          </button>
          <TaskList
            tasks={tasks}
            onStatus={async (taskId, status) =>
              setTasks(await updateTaskStatus(selected, taskId, status))
            }
          />
        </section>
      )}
    </main>
  );
}
