# DEPLOY — Clow Landing (30-min go-live)

Ship the waitlist to production. Assumes you already own the `clow-tau.vercel.app` Vercel project.

---

## 1. Files to publish (all in this repo)

```
clow_landing.html      # the landing page
api/waitlist.js        # POST endpoint — writes to Airtable
api/og.js              # dynamic OG image
vercel.json            # routing + security headers
```

## 2. Env vars (Vercel dashboard → Settings → Environment Variables)

| Key | Value | Where to get it |
|-----|-------|-----------------|
| `AIRTABLE_API_KEY` | `pat_...` | airtable.com → account → personal access token (scope: `data.records:write`) |
| `AIRTABLE_BASE_ID` | `app...` | Airtable base URL: `airtable.com/appXXX/...` |
| `AIRTABLE_TABLE` | `Waitlist` | Table name (default: Waitlist) |

**Airtable schema — one table, six fields:**
`Email` (text, unique) · `Source` (text) · `Plan` (text) · `UA` (text) · `IP` (text) · `Timestamp` (text)

## 3. Add `@vercel/og` dep (only if you deploy `api/og.js`)

```bash
# In your Vercel project root
npm init -y   # if no package.json yet
npm i @vercel/og
```

## 4. Deploy

```bash
git pull                            # get this branch
cp clow_landing.html index.html     # OR keep the vercel.json rewrite — either works
vercel --prod
```

## 5. Verify (60 seconds)

- [ ] `https://clow-tau.vercel.app/` — landing loads <3s
- [ ] Submit test email → 200 → email visible in Airtable
- [ ] Fake email `not-an-email` → inline error, no network call
- [ ] `https://clow-tau.vercel.app/api/og` → PNG loads
- [ ] Paste `https://clow-tau.vercel.app` in a fresh X compose window → card renders with title + subtitle
- [ ] View source → CSP header present (DevTools → Network → response headers)

## 6. Kill switches (if things break)

| Symptom | Fix |
|---------|-----|
| Airtable at 429 | Wait 60s; Airtable free tier = 5 req/s. Or upgrade Airtable. |
| `/api/og` 500 | Missing `@vercel/og` dep. Run `npm i @vercel/og` and redeploy. |
| Waitlist form spins forever | `/api/waitlist` returned non-2xx — offline localStorage queue already caught it; check `console.error` in Vercel logs. |
| X card renders text-only | OG image not resolving. Curl `/api/og` — expect 200 image/png. |

## 7. Post-deploy (Day 1)

1. Fire X Thread 1 from `X_THREADS.md` at 9am UTC via @XTech73781
2. Update Plausible domain to `clow-tau.vercel.app` (already in `<head>`)
3. Watch `airtable.com/appXXX/Waitlist` — first 100 signups get $7/mo Pro-for-life
4. Update `Clow_GTM_Blueprint.md` metrics dashboard end of Week 1

---

*Deploy checklist v1.0 · Ship in <30 min · KafCa mode*
