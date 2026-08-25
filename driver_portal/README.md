# Rideality Driver Web Portal

Browser replica of the **driver mobile app** for testing without a second phone.
Uses the same live API (`http://65.21.177.122:3000`) via a Vite proxy (avoids CORS).

## Run

```bash
cd driver_portal
npm install
npm run dev
```

Open **http://localhost:5173**

## What you can test

1. **Phone + OTP** (country/region, send/verify)
2. **Identity** — city → company list/search → company detail (logo, phone, WhatsApp, email, ratings)
3. **Join driver** — `POST /onboarding/driver` with `fleetRegionId` as `regionId`
4. **Dashboard** — go online/offline, service modes
5. **Documents** — status from `document_status` / `documents_approved` (upload still needs the mobile camera flow)

## Notes

- Camera / ML Kit selfie OCR is **not** replicated on web.
- Session tokens are stored in `localStorage`.
- API calls go to `/api/v1/...` and are proxied to the backend.
