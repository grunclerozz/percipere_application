# Web app API contract

The Percipere app talks to the separate web admin app at `API_BASE_URL`. The app never
calls Gemini (or any AI service) directly and never holds an API key: the web app does.
Until the web app exists the app uses mocks (`USE_MOCK_API=true`, the default).

## `POST /api/describe-image` — detailed image description (Maglarawan)

Request, `multipart/form-data`:

| Field | Type | Notes |
|---|---|---|
| `image` | file | JPEG, longest side ≤ 1600 px (resized and compressed by the app) |
| `language` | `fil` \| `en` | the user's voice language; the description must be in it |
| `user_id` | string | the logged-in user's id; **absent for guests** |
| `guest` | `true` | sent instead of `user_id` for guests: treat as anonymous |

Response `200`, JSON:

```json
{ "description": "Mukhang isang mesa na may …", "has_text": true }
```

- `description`: plain text, ready to be read aloud (no markdown, no lists).
- `has_text`: whether readable text is visible in the image.

Errors: any non-2xx or a body without `description` is treated as "try later".

### Recommended Gemini instructions (set by the web app)

- Describe the image clearly and briefly for a visually impaired listener, in the
  requested language (`fil` = Filipino, `en` = English). Plain sentences, no formatting.
- Start with "Mukhang…" / "It looks like…": it is an estimate.
- Mention any visible text, and say what it is about.
- Do **not** guess who a person is; describe them (clothing, what they are doing).
- For medicines, money, or anything safety-related, add a reminder to confirm with
  someone trusted before using it ("Paalala: kumpirmahin ito sa taong pinagkakatiwalaan
  mo bago gamitin." / "Reminder: please confirm this with someone you trust first.").

### Privacy

The app asks the user once (spoken) before the first upload: the image goes to the
Percipere server and to Google's service. The answer is saved per user and can be
changed in Settings. Guests' requests are anonymous.
