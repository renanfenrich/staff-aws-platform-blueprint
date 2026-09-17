import { useState } from "react";
import { createRoot } from "react-dom/client";
import { api } from "./api.js";

type Project = { id: string; name: string };
type Task = { id: string; title: string; status: string };
function App() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [projects, setProjects] = useState<Project[]>([]);
  const [selected, setSelected] = useState<Project>();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [name, setName] = useState("");
  const [title, setTitle] = useState("");
  const [error, setError] = useState("");
  const load = () =>
    api<{ projects: Project[] }>("/api/projects")
      .then((x) => setProjects(x.projects))
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
  async function open(p: Project) {
    setSelected(p);
    setTasks((await api<{ tasks: Task[] }>(`/api/projects/${p.id}/tasks`)).tasks);
  }
  return (
    <main>
      <h1>Project tracker</h1>
      <p>{error}</p>
      <input placeholder="email" onChange={(e) => setEmail(e.target.value)} />
      <input
        placeholder="password"
        type="password"
        onChange={(e) => setPassword(e.target.value)}
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
        onChange={(e) => setName(e.target.value)}
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
      {projects.map((p) => (
        <button type="button" key={p.id} onClick={() => open(p)}>
          {p.name}
        </button>
      ))}
      {selected && (
        <section>
          <h2>{selected.name}</h2>
          <input
            placeholder="task title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
          <button
            type="button"
            onClick={async () => {
              await api(`/api/projects/${selected.id}/tasks`, {
                method: "POST",
                body: JSON.stringify({ title }),
              });
              open(selected);
            }}
          >
            Add task
          </button>
          {tasks.map((t) => (
            <p key={t.id}>
              {t.title}{" "}
              <select
                value={t.status}
                onChange={async (e) => {
                  await api(`/api/projects/${selected.id}/tasks/${t.id}`, {
                    method: "PATCH",
                    body: JSON.stringify({ status: e.target.value }),
                  });
                  open(selected);
                }}
              >
                <option>todo</option>
                <option>in_progress</option>
                <option>done</option>
              </select>
            </p>
          ))}
        </section>
      )}
    </main>
  );
}
const root = document.getElementById("root");
if (!root) throw new Error("Missing application root");
createRoot(root).render(<App />);
