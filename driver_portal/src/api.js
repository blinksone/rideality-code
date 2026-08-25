const API_BASE = '/api/v1';
const MEDIA_HOST = '';

const KEYS = {
  access: 'rd_access',
  refresh: 'rd_refresh',
  session: 'rd_session',
  phone: 'rd_phone',
  regionCode: 'rd_region_code',
  countryRegionId: 'rd_country_region_id',
  companyName: 'rd_fleet_company',
  cityName: 'rd_fleet_city',
};

export const storage = {
  get(key) {
    return localStorage.getItem(key);
  },
  set(key, value) {
    if (value == null || value === '') localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  },
  clearAuth() {
    Object.values(KEYS).forEach((k) => localStorage.removeItem(k));
  },
  keys: KEYS,
};

export function mediaUrl(path) {
  if (!path) return null;
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return `${MEDIA_HOST}${path}`;
  return `${MEDIA_HOST}/${path}`;
}

function unwrapList(json) {
  const data = json?.data;
  if (Array.isArray(data)) return data;
  if (data?.items && Array.isArray(data.items)) return data.items;
  return [];
}

async function request(path, { method = 'GET', body, auth = true } = {}) {
  const headers = { Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (auth) {
    const token = storage.get(KEYS.access);
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  let json = null;
  try {
    json = await res.json();
  } catch (_) {
    json = null;
  }

  if (!res.ok) {
    const message =
      json?.message ||
      json?.error?.message ||
      json?.error ||
      `Request failed (${res.status})`;
    const err = new Error(typeof message === 'string' ? message : 'Request failed');
    err.status = res.status;
    err.payload = json;
    throw err;
  }

  return json ?? {};
}

export const api = {
  listRegions: () =>
    request('/auth/regions', { auth: false }).then((j) => unwrapList(j)),

  sendOtp: (phone, regionCode) =>
    request('/auth/otp/send', {
      auth: false,
      method: 'POST',
      body: { phone, regionCode },
    }),

  verifyOtp: (phone, code, regionCode) =>
    request('/auth/otp/verify', {
      auth: false,
      method: 'POST',
      body: { phone, code, regionCode },
    }),

  getMe: () => request('/users/me'),
  getOnboarding: () => request('/onboarding/status'),
  getDriver: () => request('/users/me/driver'),
  listDocuments: () =>
    request('/users/me/documents').then((j) => unwrapList(j)),

  listCities: (regionId) =>
    request(`/fleet/cities?regionId=${encodeURIComponent(regionId)}`, {
      auth: false,
    }).then((j) => unwrapList(j)),

  listCompanies: (cityId, search = '') => {
    const qs = new URLSearchParams({
      cityId,
      sort: 'top',
      limit: '20',
    });
    if (search.trim()) qs.set('search', search.trim());
    return request(`/fleet/companies?${qs}`, { auth: false }).then((j) =>
      unwrapList(j),
    );
  },

  getCompanyPublic: (companyId, cityId) =>
    request(
      `/fleet/companies/${companyId}/public?cityId=${encodeURIComponent(cityId)}`,
      { auth: false },
    ).then((j) => j.data || j),

  completeDriver: (body) =>
    request('/onboarding/driver', { method: 'POST', body }),

  setAvailability: (isOnline, modes = ['rides', 'cargo']) =>
    request('/users/me/driver/availability', {
      method: 'PATCH',
      body: { isOnline, modes },
    }),

  switchMode: (activeMode) =>
    request('/users/me/mode', {
      method: 'PATCH',
      body: { activeMode },
    }),

  recordConsent: () =>
    request('/users/me/consent', {
      method: 'POST',
      body: {
        consents: [
          { type: 'terms_of_use', version: '1.0', accepted: true },
          { type: 'privacy_policy', version: '1.0', accepted: true },
        ],
      },
    }),
};

export function documentStatusLabel(onboarding = {}) {
  const status = String(onboarding.document_status || onboarding.documentStatus || '')
    .toLowerCase();
  const uploaded =
    onboarding.documents_uploaded === true ||
    onboarding.documentsUploaded === true;
  const approved =
    onboarding.documents_approved === true ||
    onboarding.documentsApproved === true;

  switch (status) {
    case 'missing':
      return 'Upload required';
    case 'pending':
      return 'Waiting for review';
    case 'approved':
      return 'Approved';
    case 'rejected':
    case 'expired':
      return 'Reupload';
    default:
      if (approved) return 'Approved';
      if (uploaded) return 'Waiting for review';
      return 'Upload required';
  }
}

export function stars(avg = 0) {
  const n = Math.round(Math.max(0, Math.min(5, Number(avg) || 0)));
  return '★'.repeat(n) + '☆'.repeat(5 - n);
}
