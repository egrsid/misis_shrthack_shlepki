# Tech Support Hackathon API

Minimal FastAPI backend for an electronics-store support app. Swift sends one customer message; the LLM splits it into individual issues and extracts entities, then the rules in `core/triage.py` decide which required fields are missing, what status each issue gets and what the customer is asked. Everything is stored in SQLite and returned as JSON.

## Project structure

```text
app/
├── api/
│   ├── deps.py              # FastAPI dependencies (database session)
│   └── routes/issues.py     # All support-issue endpoints
├── core/
│   ├── config.py            # .env settings
│   ├── database.py          # SQLite engine and SQLAlchemy base
│   └── triage.py            # Deterministic rules: required fields, status, clarification
├── models/issue.py          # SQLite table definition
├── schemas/issue.py         # Request/response and strict LLM JSON schemas
├── services/
│   ├── llm.py               # Yandex AI Studio calls only
│   └── fake_llm.py          # Offline stand-in, enabled with USE_FAKE_LLM=1
└── main.py                  # App setup and route registration
```

## What is included

- `POST /analyze` — split a message, triage every issue, save them, and return one clarification covering all the gaps.
- `GET /issues` — all issues (the operator's feed).
- `GET /users/{user_id}/issues` — a user's issues.
- `GET /issues/{issue_id}` — a single issue.
- `PATCH /issues/{issue_id}` — update title, description, category, priority, status, or `slots`. Writing a slot re-runs triage, so `missing` and the status are recomputed.
- `POST /issues/{issue_id}/generate-reply` — create and save a Russian reply draft.
- `POST /issues/{issue_id}/reply` — save the operator's final manual or edited reply.
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
- `USE_FAKE_LLM=1` swaps the model for a keyword-based stand-in, so the whole flow
  runs with no API key and survives a dead network during a demo. The triage rules
  are unchanged in that mode — only the text understanding is faked.
- Statuses are `new`, `awaiting_info`, `in_progress`, `resolved`, `closed`. Sending a
  final reply moves an issue to `resolved`.
