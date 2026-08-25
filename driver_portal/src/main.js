import {
  api,
  documentStatusLabel,
  mediaUrl,
  stars,
  storage,
} from './api.js';

const app = document.getElementById('app');

const state = {
  screen: 'boot',
  toast: null,
  loading: false,
  error: null,

  regions: [],
  region: null,
  phoneLocal: '',
  otp: '',
  devCode: null,

  cities: [],
  city: null,
  companies: [],
  companySearch: '',
  company: null,
  companyDetail: null,

  fullName: '',
  email: '',
  dob: '',
  acceptTerms: true,

  me: null,
  onboarding: null,
  driver: null,
  documents: [],
  modes: ['rides', 'cargo'],
  tab: 'home',

  location: null, // { lat, lng, accuracy, updatedAt }
  locationError: null,
  locationLoading: false,
};

function toast(msg) {
  state.toast = msg;
  render();
  setTimeout(() => {
    if (state.toast === msg) {
      state.toast = null;
      render();
    }
  }, 2800);
}

function setScreen(screen) {
  state.screen = screen;
  state.error = null;
  render();
  if (screen === 'dashboard' && state.tab === 'home') {
    refreshLocation(false);
  }
}

function refreshLocation(forceToast = false) {
  if (!navigator.geolocation) {
    state.locationError = 'Geolocation is not supported in this browser';
    state.locationLoading = false;
    render();
    if (forceToast) toast(state.locationError);
    return;
  }

  state.locationLoading = true;
  state.locationError = null;
  render();

  navigator.geolocation.getCurrentPosition(
    (pos) => {
      state.location = {
        lat: pos.coords.latitude,
        lng: pos.coords.longitude,
        accuracy: pos.coords.accuracy,
        updatedAt: Date.now(),
      };
      state.locationLoading = false;
      state.locationError = null;
      render();
      if (forceToast) toast('Location updated');
    },
    (err) => {
      state.locationLoading = false;
      state.locationError =
        err.code === 1
          ? 'Location permission denied — allow location for this site'
          : err.code === 2
            ? 'Location unavailable'
            : 'Could not get current location';
      render();
      if (forceToast) toast(state.locationError);
    },
    {
      enableHighAccuracy: true,
      timeout: 15000,
      maximumAge: forceToast ? 0 : 30000,
    },
  );
}

function shell({ title = 'Rideality', back = null, body, footer = '', tabs = null }) {
  return `
    <div class="shell">
      <div class="topbar">
        ${back ? `<button class="back" data-action="${back}">←</button>` : '<span style="width:36px"></span>'}
        <div class="brand">${title}</div>
        <span style="width:36px"></span>
      </div>
      <div class="content">${body}</div>
      ${footer ? `<div class="footer">${footer}</div>` : ''}
      ${tabs || ''}
    </div>
    ${state.toast ? `<div class="toast">${escapeHtml(state.toast)}</div>` : ''}
  `;
}

function escapeHtml(s) {
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function stepper(current, labels) {
  return `
    <div class="stepper">
      ${labels
        .map((label, i) => {
          const n = i + 1;
          const cls = n < current ? 'done' : n === current ? 'current' : '';
          const mark = n < current ? '✓' : String(n);
          return `<div class="step ${cls}"><div class="dot">${mark}</div>${label}</div>`;
        })
        .join('')}
    </div>
  `;
}

function tabsBar(active) {
  const items = [
    ['home', '🏠', 'Home'],
    ['docs', '📄', 'Docs'],
    ['menu', '☰', 'Menu'],
    ['logout', '⎋', 'Logout'],
  ];
  return `
    <div class="tabs">
      ${items
        .map(
          ([id, icon, label]) => `
        <button class="tab ${active === id ? 'active' : ''}" data-tab="${id}">
          <span>${icon}</span>${label}
        </button>`,
        )
        .join('')}
    </div>
  `;
}

function onboardingMap(raw) {
  const data = raw?.data || raw || {};
  const nested = data.onboarding || data;
  return { ...nested, ...data };
}

async function bootstrap() {
  const token = storage.get(storage.keys.access);
  if (!token) {
    setScreen('welcome');
    return;
  }
  try {
    state.loading = true;
    render();
    const [meRes, onbRes] = await Promise.all([
      api.getMe(),
      api.getOnboarding().catch(() => ({})),
    ]);
    state.me = meRes.data || meRes;
    state.onboarding = onboardingMap(onbRes);
    try {
      const d = await api.getDriver();
      state.driver = d.data || d;
    } catch (_) {
      state.driver = null;
    }

    const isDriver =
      state.onboarding?.is_driver ||
      state.onboarding?.isDriver ||
      state.me?.activeMode === 'driver' ||
      !!state.driver?.onboardingStatus;

    if (!isDriver && !state.onboarding?.personal_info && !state.me?.fullName) {
      setScreen('identity');
      await loadCitiesForStoredRegion();
      return;
    }

    if (
      isDriver &&
      !(state.onboarding?.personal_info || state.me?.fullName) &&
      !state.driver
    ) {
      setScreen('identity');
      await loadCitiesForStoredRegion();
      return;
    }

    setScreen('dashboard');
  } catch (e) {
    storage.clearAuth();
    setScreen('welcome');
    toast(e.message || 'Session expired');
  } finally {
    state.loading = false;
    render();
  }
}

async function loadRegions() {
  state.regions = await api.listRegions();
  const storedId = storage.get(storage.keys.countryRegionId);
  const storedCode = storage.get(storage.keys.regionCode) || 'PK';
  state.region =
    state.regions.find((r) => r.id === storedId) ||
    state.regions.find((r) => String(r.code).toUpperCase() === storedCode.toUpperCase()) ||
    state.regions.find((r) => r.code === 'PK') ||
    state.regions[0] ||
    null;
}

async function loadCitiesForStoredRegion() {
  const regionId =
    storage.get(storage.keys.countryRegionId) || state.region?.id;
  if (!regionId) return;
  state.cities = await api.listCities(regionId);
}

function buildPhone() {
  const prefix = state.region?.phonePrefix || '+92';
  const local = state.phoneLocal.replace(/\D/g, '');
  const p = prefix.startsWith('+') ? prefix : `+${prefix}`;
  if (local.startsWith(p.replace('+', ''))) return `+${local}`;
  return `${p}${local}`;
}

function renderWelcome() {
  return shell({
    body: `
      <h1>Drive with Rideality</h1>
      <p class="hint">Web replica of the driver app for testing without a second phone. Same live APIs.</p>
      <div class="banner">
        <div>🚗</div>
        <div>
          <strong>Driver testing portal</strong>
          <div class="hint">Phone → OTP → City/Company → Dashboard & Documents</div>
        </div>
      </div>
    `,
    footer: `
      <button class="btn primary" data-action="go-phone">Continue as driver</button>
      <div style="height:10px"></div>
      <button class="btn ghost" data-action="go-login">I already have an account</button>
    `,
  });
}

function renderPhone() {
  return shell({
    back: 'go-welcome',
    body: `
      ${stepper(1, ['Phone', 'OTP', 'Identity', 'Docs'])}
      <h2>Your phone number</h2>
      <p class="hint">Country comes from the region you pick here (same as mobile).</p>
      <label class="field">
        <span>Country / region</span>
        <select id="region">
          ${state.regions
            .map(
              (r) =>
                `<option value="${r.id}" ${state.region?.id === r.id ? 'selected' : ''}>${escapeHtml(r.name)} (${escapeHtml(r.code)}) ${escapeHtml(r.phonePrefix || '')}</option>`,
            )
            .join('')}
        </select>
      </label>
      <label class="field">
        <span>Mobile number</span>
        <input id="phone" inputmode="numeric" placeholder="3XXXXXXXXX" value="${escapeHtml(state.phoneLocal)}" />
      </label>
      ${state.error ? `<div class="error-text">${escapeHtml(state.error)}</div>` : ''}
    `,
    footer: `<button class="btn primary" data-action="send-otp" ${state.loading ? 'disabled' : ''}>${state.loading ? 'Sending…' : 'Send OTP'}</button>`,
  });
}

function renderOtp() {
  return shell({
    back: 'go-phone',
    body: `
      ${stepper(2, ['Phone', 'OTP', 'Identity', 'Docs'])}
      <h2>Enter verification code</h2>
      <p class="hint">Sent to ${escapeHtml(buildPhone())}</p>
      ${state.devCode ? `<div class="banner amber"><div>Dev OTP: <strong>${escapeHtml(state.devCode)}</strong></div></div>` : ''}
      <label class="field">
        <span>OTP</span>
        <input id="otp" inputmode="numeric" maxlength="6" placeholder="6-digit code" value="${escapeHtml(state.otp)}" />
      </label>
      ${state.error ? `<div class="error-text">${escapeHtml(state.error)}</div>` : ''}
    `,
    footer: `
      <button class="btn primary" data-action="verify-otp" ${state.loading ? 'disabled' : ''}>${state.loading ? 'Verifying…' : 'Verify & continue'}</button>
      <div style="height:10px"></div>
      <button class="btn ghost" data-action="send-otp">Resend code</button>
    `,
  });
}

function renderIdentity() {
  const canContinue =
    state.city &&
    state.company &&
    state.fullName.trim().length >= 2 &&
    state.dob &&
    state.acceptTerms;

  return shell({
    body: `
      ${stepper(3, ['Phone', 'OTP', 'Identity', 'Docs'])}
      <h2>Driver identity</h2>
      <p class="hint">Join a city fleet. Country was already set on the phone screen.</p>
      <div class="banner"><div>🏢</div><div>Select your city, then pick a fleet company.</div></div>

      <label class="field">
        <span>City *</span>
        <select id="city">
          <option value="">Select city</option>
          ${state.cities
            .map((c) => {
              const label = c.province?.name
                ? `${c.name} · ${c.province.name}`
                : c.name;
              return `<option value="${c.id}" ${state.city?.id === c.id ? 'selected' : ''}>${escapeHtml(label)}</option>`;
            })
            .join('')}
        </select>
      </label>
      ${
        state.city && !state.cities.length
          ? '<p class="hint">No fleets in this city yet</p>'
          : ''
      }

      ${
        state.company
          ? `<div class="card" style="margin-bottom:14px">
              <strong>${escapeHtml(state.company.legalName)}</strong>
              <div class="stars">${stars(state.company.ratingAvg)} ${(state.company.ratingAvg || 0).toFixed?.(1) || state.company.ratingAvg || 0}</div>
              <div class="hint">${state.company.driverCount || 0} drivers</div>
              <button class="btn secondary" style="margin-top:10px" data-action="open-companies">Change company</button>
            </div>`
          : state.city
            ? `<button class="btn secondary" data-action="open-companies">Select fleet company</button>`
            : ''
      }

      <label class="field" style="margin-top:16px">
        <span>Full name *</span>
        <input id="fullName" value="${escapeHtml(state.fullName)}" placeholder="Full name" />
      </label>
      <label class="field">
        <span>Date of birth * (18+)</span>
        <input id="dob" type="date" value="${escapeHtml(state.dob)}" />
      </label>
      <label class="field">
        <span>Email (optional)</span>
        <input id="email" type="email" value="${escapeHtml(state.email)}" placeholder="optional@email.com" />
      </label>
      <label style="display:flex;gap:10px;align-items:flex-start;margin:8px 0 16px">
        <input type="checkbox" id="terms" ${state.acceptTerms ? 'checked' : ''} style="width:auto;margin-top:3px" />
        <span class="hint">I accept Terms of Service & Privacy Policy</span>
      </label>
      ${state.error ? `<div class="error-text">${escapeHtml(state.error)}</div>` : ''}
    `,
    footer: `<button class="btn primary" data-action="join-driver" ${!canContinue || state.loading ? 'disabled' : ''}>${state.loading ? 'Submitting…' : 'Continue'}</button>`,
  });
}

function renderCompanies() {
  return shell({
    back: 'go-identity',
    title: state.city?.name || 'Fleet companies',
    body: `
      <label class="field">
        <span>Search companies</span>
        <input id="companySearch" placeholder="Search fleet companies" value="${escapeHtml(state.companySearch)}" />
      </label>
      ${
        state.loading
          ? '<div class="loading">Loading companies…</div>'
          : !state.companies.length
            ? '<div class="loading">No fleet companies in this city</div>'
            : `<div class="list">
                ${state.companies
                  .map((c) => {
                    const logo = mediaUrl(c.logoUrl);
                    return `
                      <button class="list-item" data-company="${c.id}">
                        <div class="logo">${logo ? `<img src="${logo}" alt="" />` : (c.legalName || '?')[0]}</div>
                        <div>
                          <strong>${escapeHtml(c.legalName)}</strong>
                          <div class="stars">${stars(c.ratingAvg)} ${(Number(c.ratingAvg) || 0).toFixed(1)} (${c.ratingCount || 0})</div>
                          <div class="hint">${c.driverCount || 0} drivers</div>
                        </div>
                      </button>`;
                  })
                  .join('')}
              </div>`
      }
    `,
  });
}

function renderCompanyDetail() {
  const c = state.companyDetail;
  if (!c) return shell({ body: '<div class="loading">Loading…</div>' });
  const logo = mediaUrl(c.logoUrl);
  return shell({
    back: 'open-companies',
    title: 'Company details',
    body: `
      <div class="card">
        <div style="display:flex;gap:14px;align-items:flex-start">
          <div class="logo" style="width:72px;height:72px;font-size:1.4rem">${logo ? `<img src="${logo}" alt="" />` : (c.legalName || '?')[0]}</div>
          <div>
            <h2 style="margin:0 0 8px">${escapeHtml(c.legalName)}</h2>
            <div class="stars">${stars(c.ratingAvg)}</div>
            <div class="hint">${(Number(c.ratingAvg) || 0).toFixed(1)} • ${c.ratingCount || 0} ratings</div>
            <div class="hint">${c.driverCount || 0} drivers</div>
          </div>
        </div>
      </div>
      <div style="height:14px"></div>
      ${c.phone ? `<div class="card"><div class="hint">Phone</div><strong>${escapeHtml(c.phone)}</strong>
        <div class="row" style="margin-top:10px">
          <a class="btn secondary" href="tel:${escapeHtml(c.phone)}">Call</a>
          <a class="btn secondary" target="_blank" rel="noreferrer" href="https://wa.me/${String(c.phone).replace(/\D/g, '')}">WhatsApp</a>
        </div></div><div style="height:10px"></div>` : ''}
      ${c.email ? `<div class="card"><div class="hint">Email</div><a href="mailto:${escapeHtml(c.email)}">${escapeHtml(c.email)}</a></div><div style="height:10px"></div>` : ''}
      <div class="card"><div class="hint">Address</div><strong>${escapeHtml(c.address || '—')}</strong></div>
      <h3 style="margin:18px 0 8px">Reviews</h3>
      ${
        !(c.reviews || []).length
          ? '<p class="hint">No reviews yet.</p>'
          : (c.reviews || [])
              .map(
                (r) => `
            <div class="card" style="margin-bottom:10px">
              <div class="stars">${stars(r.score)}</div>
              <div>${escapeHtml(r.comment || '')}</div>
              <div class="hint">${escapeHtml(r.reviewerName || '')}</div>
            </div>`,
              )
              .join('')
      }
    `,
    footer: `
      <button class="btn secondary" data-action="select-company">Select company</button>
      <div style="height:10px"></div>
      <button class="btn primary" data-action="join-from-detail">Join as driver</button>
    `,
  });
}

function renderDashboard() {
  const online = !!(state.driver?.isOnline || state.driver?.is_online);
  const docLabel = documentStatusLabel(state.onboarding || {});
  const name = state.me?.fullName || state.fullName || 'Driver';
  const company =
    storage.get(storage.keys.companyName) ||
    state.company?.legalName ||
    'Fleet';
  const city =
    storage.get(storage.keys.cityName) || state.city?.name || '';

  if (state.tab === 'docs') return renderDocsTab();
  if (state.tab === 'menu') return renderMenuTab();

  const loc = state.location;
  const locLabel = state.locationLoading
    ? 'Getting current location…'
    : state.locationError
      ? state.locationError
      : loc
        ? `${loc.lat.toFixed(6)}, ${loc.lng.toFixed(6)}`
        : 'Location not available yet';
  const mapsLink = loc
    ? `https://www.google.com/maps?q=${loc.lat},${loc.lng}`
    : null;

  return shell({
    title: 'Rideality',
    body: `
      <div class="map-fake">
        <div style="text-align:center;padding:16px">
          <div style="font-size:1.5rem;margin-bottom:8px">📍</div>
          <div>${loc ? 'Current location' : 'Map preview (web testing)'}</div>
          ${
            loc
              ? `<div class="hint" style="margin-top:6px">±${Math.round(loc.accuracy || 0)}m · ${escapeHtml(
                  new Date(loc.updatedAt).toLocaleTimeString(),
                )}</div>`
              : ''
          }
        </div>
      </div>
      <div class="card" style="margin-bottom:12px">
        <div class="hint">Current location</div>
        <strong style="word-break:break-all">${escapeHtml(locLabel)}</strong>
        <div class="row" style="margin-top:10px">
          <button class="btn secondary" data-action="refresh-location" ${state.locationLoading ? 'disabled' : ''}>
            ${state.locationLoading ? 'Locating…' : 'Refresh location'}
          </button>
          ${
            mapsLink
              ? `<a class="btn secondary" href="${mapsLink}" target="_blank" rel="noreferrer">Open map</a>`
              : ''
          }
        </div>
      </div>
      <div class="card">
        <div style="display:flex;justify-content:space-between;align-items:center;gap:8px">
          <div>
            <strong>${escapeHtml(name)}</strong>
            <div class="hint">${escapeHtml(company)}${city ? ` · ${escapeHtml(city)}` : ''}</div>
          </div>
          <span class="status-pill ${online ? 'online' : 'offline'}">${online ? '● Online' : '● Offline'}</span>
        </div>
        <div class="chip-row">
          ${['rides', 'cargo', 'both']
            .map((m) => {
              const active =
                m === 'both'
                  ? state.modes.includes('rides') && state.modes.includes('cargo')
                  : state.modes.length === 1 && state.modes[0] === m;
              return `<button class="chip ${active ? 'active' : ''}" data-mode="${m}">${m[0].toUpperCase()}${m.slice(1)}</button>`;
            })
            .join('')}
        </div>
        <button class="btn primary" data-action="toggle-online" ${state.loading ? 'disabled' : ''}>
          ${state.loading ? 'Updating…' : online ? 'Go offline' : 'Go online'}
        </button>
      </div>
      <div style="height:12px"></div>
      <button class="list-item" data-action="go-docs-tab">
        <div class="logo">📄</div>
        <div>
          <strong>Documents</strong>
          <div class="hint">${escapeHtml(docLabel)}</div>
        </div>
      </button>
    `,
    tabs: tabsBar('home'),
  });
}

function renderDocsTab() {
  const label = documentStatusLabel(state.onboarding || {});
  const approved =
    state.onboarding?.documents_approved === true ||
    state.onboarding?.documentsApproved === true;
  const tone = approved ? 'success' : label === 'Reupload' ? 'error' : 'amber';

  return shell({
    title: 'Documents',
    body: `
      <div class="banner ${tone}">
        <div>📄</div>
        <div>
          <strong>Document status</strong>
          <div>${escapeHtml(label)}</div>
          <div class="hint" style="margin-top:6px">
            documents_uploaded = files exist · documents_approved = Done · driver_approved = final only
          </div>
        </div>
      </div>
      <div class="card">
        <div class="hint">Onboarding flags</div>
        <div>Uploaded: <strong>${String(!!(state.onboarding?.documents_uploaded || state.onboarding?.documentsUploaded))}</strong></div>
        <div>Approved: <strong>${String(!!approved)}</strong></div>
        <div>document_status: <strong>${escapeHtml(state.onboarding?.document_status || state.onboarding?.documentStatus || '—')}</strong></div>
        <div>driver_approved: <strong>${String(!!(state.onboarding?.driver_approved || state.onboarding?.driverApproved))}</strong></div>
      </div>
      <h3 style="margin:18px 0 8px">Uploaded files</h3>
      ${
        !state.documents.length
          ? '<p class="hint">No documents returned from API (upload still uses the mobile app camera flow).</p>'
          : `<div class="list">${state.documents
              .map(
                (d) => `
              <div class="card">
                <strong>${escapeHtml(d.type || d.documentType || 'document')}</strong>
                <div class="hint">${escapeHtml(d.status || '—')}</div>
                ${d.rejectionReason ? `<div class="error-text">${escapeHtml(d.rejectionReason)}</div>` : ''}
              </div>`,
              )
              .join('')}</div>`
      }
      <div style="height:12px"></div>
      <button class="btn secondary" data-action="refresh-docs">Refresh status</button>
    `,
    tabs: tabsBar('docs'),
  });
}

function renderMenuTab() {
  const name = state.me?.fullName || 'Driver';
  const phone = state.me?.phone || storage.get(storage.keys.phone) || '';
  const company = storage.get(storage.keys.companyName) || '';
  const city = storage.get(storage.keys.cityName) || '';
  const docLabel = documentStatusLabel(state.onboarding || {});

  return shell({
    title: 'Menu',
    body: `
      <div class="card" style="margin-bottom:12px">
        <strong>${escapeHtml(name)}</strong>
        <div class="hint">${escapeHtml(phone)}</div>
        <div class="hint">${escapeHtml([company, city].filter(Boolean).join(' · '))}</div>
      </div>
      <button class="menu-item" data-action="go-docs-tab">
        <div class="icon">📄</div>
        <div class="meta">
          <strong>Documents</strong>
          <small>${escapeHtml(docLabel)}</small>
        </div>
        ›
      </button>
      <button class="menu-item" data-action="refresh-docs">
        <div class="icon">↻</div>
        <div class="meta"><strong>Refresh account</strong><small>Reload me / onboarding / driver</small></div>
        ›
      </button>
      <button class="menu-item" data-action="logout">
        <div class="icon">⎋</div>
        <div class="meta"><strong>Log out</strong></div>
        ›
      </button>
    `,
    tabs: tabsBar('menu'),
  });
}

function render() {
  if (state.screen === 'boot' || (state.loading && state.screen === 'boot')) {
    app.innerHTML = `<div class="shell"><div class="loading">Restoring session…</div></div>`;
    return;
  }

  const map = {
    welcome: renderWelcome,
    phone: renderPhone,
    otp: renderOtp,
    identity: renderIdentity,
    companies: renderCompanies,
    companyDetail: renderCompanyDetail,
    dashboard: renderDashboard,
  };

  app.innerHTML = (map[state.screen] || renderWelcome)();
  bind();
}

function bind() {
  app.querySelectorAll('[data-action]').forEach((el) => {
    el.addEventListener('click', () => onAction(el.getAttribute('data-action')));
  });
  app.querySelectorAll('[data-tab]').forEach((el) => {
    el.addEventListener('click', () => onTab(el.getAttribute('data-tab')));
  });
  app.querySelectorAll('[data-company]').forEach((el) => {
    el.addEventListener('click', () => openCompany(el.getAttribute('data-company')));
  });
  app.querySelectorAll('[data-mode]').forEach((el) => {
    el.addEventListener('click', () => {
      const m = el.getAttribute('data-mode');
      state.modes = m === 'both' ? ['rides', 'cargo'] : [m];
      render();
    });
  });

  const region = app.querySelector('#region');
  if (region) {
    region.addEventListener('change', () => {
      state.region = state.regions.find((r) => r.id === region.value) || null;
    });
  }
  const phone = app.querySelector('#phone');
  if (phone) phone.addEventListener('input', () => (state.phoneLocal = phone.value));
  const otp = app.querySelector('#otp');
  if (otp) otp.addEventListener('input', () => (state.otp = otp.value));
  const city = app.querySelector('#city');
  if (city) {
    city.addEventListener('change', async () => {
      state.city = state.cities.find((c) => c.id === city.value) || null;
      state.company = null;
      state.companyDetail = null;
      render();
      if (state.city) {
        await openCompanies();
      }
    });
  }
  const fullName = app.querySelector('#fullName');
  if (fullName) fullName.addEventListener('input', () => (state.fullName = fullName.value));
  const email = app.querySelector('#email');
  if (email) email.addEventListener('input', () => (state.email = email.value));
  const dob = app.querySelector('#dob');
  if (dob) dob.addEventListener('change', () => (state.dob = dob.value));
  const terms = app.querySelector('#terms');
  if (terms) terms.addEventListener('change', () => (state.acceptTerms = terms.checked));

  const search = app.querySelector('#companySearch');
  if (search) {
    let t;
    search.addEventListener('input', () => {
      state.companySearch = search.value;
      clearTimeout(t);
      t = setTimeout(() => loadCompanies(), 300);
    });
  }
}

async function onAction(action) {
  try {
    if (action === 'go-welcome') return setScreen('welcome');
    if (action === 'go-phone' || action === 'go-login') {
      await loadRegions();
      setScreen('phone');
      return;
    }
    if (action === 'go-identity') return setScreen('identity');
    if (action === 'send-otp') return sendOtp();
    if (action === 'verify-otp') return verifyOtp();
    if (action === 'open-companies') return openCompanies();
    if (action === 'select-company') {
      state.company = state.companyDetail;
      setScreen('identity');
      return;
    }
    if (action === 'join-from-detail') {
      state.company = state.companyDetail;
      setScreen('identity');
      return joinDriver();
    }
    if (action === 'join-driver') return joinDriver();
    if (action === 'toggle-online') return toggleOnline();
    if (action === 'refresh-location') return refreshLocation(true);
    if (action === 'go-docs-tab') {
      state.tab = 'docs';
      await refreshDocs();
      setScreen('dashboard');
      return;
    }
    if (action === 'refresh-docs') {
      await refreshSessionData();
      toast('Refreshed');
      return;
    }
    if (action === 'logout') return logout();
  } catch (e) {
    state.error = e.message;
    state.loading = false;
    toast(e.message);
    render();
  }
}

async function onTab(tab) {
  if (tab === 'logout') return logout();
  state.tab = tab;
  if (tab === 'docs') await refreshDocs();
  if (tab === 'home') refreshLocation(false);
  render();
}

async function sendOtp() {
  state.error = null;
  if (!state.region) {
    state.error = 'Select a country/region';
    return render();
  }
  if (state.phoneLocal.replace(/\D/g, '').length < 10) {
    state.error = 'Enter a valid mobile number';
    return render();
  }
  state.loading = true;
  render();
  try {
    const phone = buildPhone();
    const res = await api.sendOtp(phone, state.region.code);
    const data = res.data || res;
    state.devCode = data.devBypassCode || data.devCode || data.code || null;
    storage.set(storage.keys.phone, phone);
    storage.set(storage.keys.regionCode, state.region.code);
    storage.set(storage.keys.countryRegionId, state.region.id);
    state.loading = false;
    setScreen('otp');
    if (state.devCode) toast(`Dev OTP: ${state.devCode}`);
  } catch (e) {
    state.loading = false;
    state.error = e.message;
    render();
  }
}

async function verifyOtp() {
  state.error = null;
  if (!state.otp || state.otp.length < 4) {
    state.error = 'Enter the verification code';
    return render();
  }
  state.loading = true;
  render();
  try {
    const phone = buildPhone();
    const res = await api.verifyOtp(phone, state.otp, state.region.code);
    const data = res.data || res;
    storage.set(storage.keys.access, data.accessToken);
    storage.set(storage.keys.refresh, data.refreshToken);
    storage.set(storage.keys.session, data.sessionId);
    storage.set(storage.keys.phone, phone);
    storage.set(storage.keys.countryRegionId, state.region.id);
    try {
      await api.recordConsent();
    } catch (_) {}

    const onb = onboardingMap(data.user?.onboarding || {});
    state.onboarding = onb;
    state.me = data.user || null;
    if (data.user?.fullName) state.fullName = data.user.fullName;
    if (data.user?.email) state.email = data.user.email;

    await loadCitiesForStoredRegion();

    const alreadyDriver =
      onb.is_driver ||
      onb.isDriver ||
      data.user?.activeMode === 'driver';

    state.loading = false;
    if (alreadyDriver && (onb.documents_uploaded || onb.personal_info || onb.personalInfo)) {
      await refreshSessionData();
      setScreen('dashboard');
    } else {
      setScreen('identity');
    }
  } catch (e) {
    state.loading = false;
    state.error = e.message;
    render();
  }
}

async function openCompanies() {
  if (!state.city) {
    toast('Select a city first');
    return;
  }
  setScreen('companies');
  await loadCompanies();
}

async function loadCompanies() {
  if (!state.city) return;
  state.loading = true;
  render();
  try {
    state.companies = await api.listCompanies(state.city.id, state.companySearch);
  } catch (e) {
    toast(e.message);
    state.companies = [];
  } finally {
    state.loading = false;
    render();
  }
}

async function openCompany(id) {
  state.loading = true;
  setScreen('companyDetail');
  try {
    state.companyDetail = await api.getCompanyPublic(id, state.city.id);
  } catch (e) {
    toast(e.message);
    setScreen('companies');
  } finally {
    state.loading = false;
    render();
  }
}

function isAdult(dob) {
  const d = new Date(dob);
  if (Number.isNaN(d.getTime())) return false;
  const now = new Date();
  let age = now.getFullYear() - d.getFullYear();
  const m = now.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age -= 1;
  return age >= 18;
}

async function joinDriver() {
  state.error = null;
  if (!state.company?.fleetRegionId) {
    state.error = 'Select a company with a fleet region';
    return render();
  }
  if (!isAdult(state.dob)) {
    state.error = 'You must be at least 18 years old';
    return render();
  }
  state.loading = true;
  render();
  try {
    await api.completeDriver({
      companyId: state.company.id,
      regionId: state.company.fleetRegionId,
      fullName: state.fullName.trim(),
      dateOfBirth: state.dob,
      email: state.email.trim() || undefined,
    });
    storage.set(storage.keys.companyName, state.company.legalName);
    storage.set(storage.keys.cityName, state.city?.name || state.company.fleetRegionName || '');
    await refreshSessionData();
    state.loading = false;
    state.tab = 'home';
    setScreen('dashboard');
    toast('Driver onboarding submitted');
  } catch (e) {
    state.loading = false;
    state.error = e.message;
    toast(e.message);
    render();
  }
}

async function toggleOnline() {
  const online = !!(state.driver?.isOnline || state.driver?.is_online);
  state.loading = true;
  render();
  try {
    try {
      await api.switchMode('driver');
    } catch (_) {}
    const res = await api.setAvailability(!online, state.modes);
    state.driver = res.data || res;
    toast(!online ? "You're online" : "You're offline");
  } catch (e) {
    toast(e.message);
  } finally {
    state.loading = false;
    render();
  }
}

async function refreshDocs() {
  try {
    const onb = await api.getOnboarding();
    state.onboarding = onboardingMap(onb);
    state.documents = await api.listDocuments().catch(() => []);
  } catch (e) {
    toast(e.message);
  }
  render();
}

async function refreshSessionData() {
  const [meRes, onbRes] = await Promise.all([
    api.getMe(),
    api.getOnboarding().catch(() => ({})),
  ]);
  state.me = meRes.data || meRes;
  state.onboarding = onboardingMap(onbRes);
  try {
    const d = await api.getDriver();
    state.driver = d.data || d;
  } catch (_) {}
  state.documents = await api.listDocuments().catch(() => []);
  render();
}

function logout() {
  storage.clearAuth();
  state.me = null;
  state.driver = null;
  state.onboarding = null;
  state.company = null;
  state.city = null;
  state.tab = 'home';
  setScreen('welcome');
  toast('Logged out');
}

bootstrap();
