# Project Bobst

```
frontend/   React + Vite + TypeScript
backend/    FastAPI (Python)
```

## Backend

```sh
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/uvicorn app.main:app --reload    # http://localhost:8000
.venv/bin/python -m pytest                 # run tests
```

Copy `.env.example` to `.env` to override settings.

## Frontend

Requires Node 18+.

```sh
cd frontend
npm install
npm run dev    # http://localhost:5173
```

The dev server proxies `/api/*` to the backend on port 8000.
