# Tech Support Hackathon API

Minimal FastAPI backend for an electronics-store support app. Swift sends one customer message; the LLM splits it into individual issues and extracts entities, then the rules in `core/triage.py` decide which required fields are missing, what status each issue gets and what the customer is asked. Everything is stored in SQLite and returned as JSON.

## Project structure

```text
app/
├── api/
│   ├── deps.py              # FastAPI dependencies (database session)
│   └── routes/
│       ├── auth.py          # Registration and login
│       ├── issues.py        # All support-issue endpoints
│       └── views.py         # Per-client product viewing history
├── core/
│   ├── config.py            # .env settings
│   ├── database.py          # SQLite engine and SQLAlchemy base
│   ├── security.py          # PBKDF2 password hashing
│   ├── seed.py              # Seeds the default operator account
│   └── triage.py            # Deterministic rules: required fields, status, clarification
├── models/                  # SQLite tables: issues, users, product_views
├── schemas/                 # Request/response and strict LLM JSON schemas
├── services/
│   ├── llm.py               # Yandex AI Studio calls only
│   └── fake_llm.py          # Offline stand-in, enabled with USE_FAKE_LLM=1
└── main.py                  # App setup and route registration
```

## What is included

- `POST /analyze` — split a message, triage every issue, save them, and return one clarification covering all the gaps. Complete issues are handed to the operator immediately; incomplete ones stay in status `collecting`.
- `POST /requests/{request_id}/clarify` — apply the customer's answer to the fields a request is still waiting for, and submit each issue as soon as it is complete.
- `GET /issues` — the operator's feed. Excludes `collecting`, because an incomplete request is not the operator's work yet (`?include_collecting=true` for debugging).
- `GET /users/{user_id}/issues` — a user's issues.
- `GET /issues/{issue_id}` — a single issue.
- `PATCH /issues/{issue_id}` — update title, description, category, priority, status, or `slots`. Writing a slot re-runs triage, so `missing` and the status are recomputed.
- `POST /issues/{issue_id}/generate-reply` — create and save a Russian reply draft.
- `POST /issues/{issue_id}/reply` — save the operator's final manual or edited reply.
- `POST /auth/register` — create a client account; the password is stored hashed.
- `POST /auth/login` — check credentials, optionally pinned to a role.
- `POST /users/{user_id}/views` — record that a client opened a product.
- `GET /users/{user_id}/views` — that client's own viewing history.
- `DELETE /users/{user_id}/views` — clear it.
- `GET /health` — simple availability check.

## Run locally

Requires Python 3.10+.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Open `.env` and set `YANDEX_API_KEY` and `YANDEX_CLOUD_FOLDER` to your real Yandex AI Studio values. The key is never stored in the source code. Then start the server:

```bash
uvicorn app.main:app --reload
```

The API is available at `http://127.0.0.1:8000`; interactive documentation is at `http://127.0.0.1:8000/docs`.

## Swift request example

```http
POST /analyze
Content-Type: application/json

{
  "user_id": 1,
  "text": "Ноутбук сильно греется, зарядка иногда не работает и хочу узнать про возврат"
}
```

Example response (every issue is already stored in `support.db`):

```json
{
  "request_id": "0f1c8f8e-5e1a-4c6d-9b0e-2b5f2f1a77c2",
  "issues": [
    {
      "id": 1,
      "user_id": 1,
      "original_text": "Ноутбук сильно греется, зарядка иногда не работает и хочу узнать про возврат",
      "title": "Перегрев ноутбука",
      "description": "Пользователь сообщает о сильном нагреве ноутбука.",
      "category": "technical",
      "priority": "high",
      "status": "new",
      "slots": { "model": "ноутбук", "issue": "перегрев" },
      "missing": [],
      "generated_reply": null,
      "final_reply": null,
      "request_id": "0f1c8f8e-5e1a-4c6d-9b0e-2b5f2f1a77c2",
      "group_index": 1,
      "group_total": 2,
      "created_at": "2026-09-12T10:00:00",
      "updated_at": "2026-09-12T10:00:00"
    }
  ],
  "clarification": "Для оформления возврата укажите, пожалуйста: номер заказа и причину возврата."
}
```

`slots` holds what the customer actually stated — a field is `null` when it was not
in the message, never a guess. `missing` is computed from the `REQUIRED` table in
`core/triage.py`, and an issue with anything missing gets status `awaiting_info`.

## Other requests

```bash
# All issues
curl http://127.0.0.1:8000/issues

# Issues for user 1
curl http://127.0.0.1:8000/users/1/issues

# Update status
curl -X PATCH http://127.0.0.1:8000/issues/1 \
  -H "Content-Type: application/json" \
  -d '{"status":"in_progress"}'

# Fill in a missing field; missing and status are recomputed
curl -X PATCH http://127.0.0.1:8000/issues/1 \
  -H "Content-Type: application/json" \
  -d '{"slots":{"serial_number":"SN-4481-XZ"}}'

# The customer answers a clarifying question
curl -X POST http://127.0.0.1:8000/requests/<request_id>/clarify \
  -H "Content-Type: application/json" \
  -d '{"text":"Серийный номер SN-4481-XZ, купил 12.08.2026"}'

# Generate a customer reply draft
curl -X POST http://127.0.0.1:8000/issues/1/generate-reply

# Save the final reply written or edited by the operator
curl -X POST http://127.0.0.1:8000/issues/1/reply \
  -H "Content-Type: application/json" \
  -d '{"text":"Здравствуйте! Подскажите номер заказа, пожалуйста."}'
```

## Notes

- SQLite database is created automatically as `support.db` when the server starts.
- The LLM response is parsed against Pydantic models (`IssueAnalysis` and `ExtractedIssue`), so only the permitted categories and priorities reach the database.
- The default model is Alice AI LLM: `gpt://<folder_id>/aliceai-llm`.
- Change `YANDEX_MODEL` in `.env` if you want another Yandex AI Studio model that supports Structured Outputs.
- `allow_origins=["*"]` is deliberate for local hackathon development; lock it down before deploying.
- Passwords are hashed with PBKDF2-SHA256 (200k iterations, per-user salt) from the
  standard library — no extra dependency, and no plain text in the database.
- There are no sessions or tokens: after login the app keeps the returned user id,
  and the issue endpoints are not access-controlled. A deliberate hackathon
  limitation — the point of the case is triage, not authorisation.
- The operator account is seeded from `OPERATOR_LOGIN` / `OPERATOR_PASSWORD`;
  `/auth/register` only ever creates clients.
- `USE_FAKE_LLM=1` swaps the model for a keyword-based stand-in, so the whole flow
  runs with no API key and survives a dead network during a demo. The triage rules
  are unchanged in that mode — only the text understanding is faked.
- Statuses are `collecting`, `new`, `awaiting_info`, `in_progress`, `resolved`, `closed`.
  `collecting` means the chat is still gathering required fields and the operator
  cannot see the issue. Sending a final reply moves an issue to `resolved`.
- Re-running triage never pulls a submitted issue back into `collecting`: a gap that
  appears later is shown to the operator instead of hiding the issue.
