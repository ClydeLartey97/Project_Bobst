import { useEffect, useState } from "react";
import { getHealth } from "./api";

export default function App() {
  const [status, setStatus] = useState("checking…");

  useEffect(() => {
    getHealth()
      .then((data) => setStatus(data.status))
      .catch(() => setStatus("unreachable"));
  }, []);

  return (
    <main>
      <h1>Project Bobst</h1>
      <p>Backend: {status}</p>
    </main>
  );
}
