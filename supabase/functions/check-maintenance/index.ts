// Runs daily via pg_cron. Reads all buses from Firestore, checks insurance
// expiry and oil-change conditions, then calls send-push for each alert.

const INSURANCE_WARN_DAYS = 30  // warn owner 30 days before expiry
const VIDANGE_WARN_KM     = 4500 // warn at 4500 km gap (limit is 5000)
const VIDANGE_WARN_DAYS   = 150  // warn after 150 days since last oil change

Deno.serve(async (req) => {
  // Only accept calls bearing the Supabase service_role JWT (from pg_cron)
  const auth = req.headers.get('Authorization') ?? ''
  if (!auth.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
  const accessToken = await getFirebaseAccessToken(serviceAccount)

  // ── Query Firestore for all buses ─────────────────────────────────────────
  const firestoreUrl =
    `https://firestore.googleapis.com/v1/projects/${serviceAccount.project_id}` +
    `/databases/(default)/documents/buses?pageSize=300`

  const fsRes = await fetch(firestoreUrl, {
    headers: { 'Authorization': `Bearer ${accessToken}` },
  })

  if (!fsRes.ok) {
    const err = await fsRes.text()
    console.error('Firestore query failed:', err)
    return new Response(JSON.stringify({ error: 'Firestore query failed' }), { status: 502 })
  }

  const { documents = [] } = await fsRes.json()
  const today = new Date()

  type Alert = { user_id: string; title: string; body: string }
  const alerts: Alert[] = []

  for (const doc of documents) {
    const f = doc.fields ?? {}
    const ownerId: string  = f.ownerId?.stringValue ?? ''
    const busName: string  = f.busName?.stringValue ?? 'Bus'
    const lineName: string = f.lineName?.stringValue ?? ''

    if (!ownerId) continue

    // ── Insurance expiry ──────────────────────────────────────────────────
    const assuranceTs: string | undefined = f.assuranceEndDate?.timestampValue
    if (assuranceTs) {
      const expiry   = new Date(assuranceTs)
      const daysLeft = Math.ceil((expiry.getTime() - today.getTime()) / 86_400_000)

      if (daysLeft <= 0) {
        alerts.push({
          user_id: ownerId,
          title: '🚨 Assurance expirée',
          body:  `L'assurance de ${busName} (${lineName}) est expirée depuis ${Math.abs(daysLeft)} jour(s).`,
        })
      } else if (daysLeft <= INSURANCE_WARN_DAYS) {
        alerts.push({
          user_id: ownerId,
          title: '⚠️ Assurance expire bientôt',
          body:  `L'assurance de ${busName} expire dans ${daysLeft} jour(s).`,
        })
      }
    }

    // ── Oil-change by kilometres ───────────────────────────────────────────
    const lastKm   = parseInt(f.lastVidangeKm?.integerValue ?? '0', 10)
    const currentKm = parseInt(f.currentKm?.integerValue    ?? '0', 10)
    if (lastKm > 0 && currentKm > lastKm) {
      const kmSince = currentKm - lastKm
      if (kmSince >= VIDANGE_WARN_KM) {
        alerts.push({
          user_id: ownerId,
          title: '🔧 Vidange requise (km)',
          body:  `${busName} a parcouru ${kmSince} km depuis la dernière vidange.`,
        })
      }
    }

    // ── Oil-change by date ────────────────────────────────────────────────
    const vidangeTs: string | undefined = f.lastVidangeDate?.timestampValue
    if (vidangeTs) {
      const vidangeDate = new Date(vidangeTs)
      const daysSince   = Math.floor((today.getTime() - vidangeDate.getTime()) / 86_400_000)
      if (daysSince >= VIDANGE_WARN_DAYS) {
        alerts.push({
          user_id: ownerId,
          title: '🔧 Vidange requise (date)',
          body:  `La dernière vidange de ${busName} remonte à ${daysSince} jours.`,
        })
      }
    }
  }

  // ── Fire push notifications ───────────────────────────────────────────────
  const supabaseUrl      = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  const results = await Promise.allSettled(
    alerts.map((alert) =>
      fetch(`${supabaseUrl}/functions/v1/send-push`, {
        method:  'POST',
        headers: {
          'Content-Type':  'application/json',
          'Authorization': `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify(alert),
      }),
    ),
  )

  const sent   = results.filter((r) => r.status === 'fulfilled').length
  const failed = results.length - sent

  console.log(`check-maintenance: ${documents.length} buses, ${alerts.length} alerts, ${sent} sent, ${failed} failed`)

  return new Response(
    JSON.stringify({ buses_checked: documents.length, alerts_found: alerts.length, sent, failed }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})

// ── Firebase OAuth2 (same implementation as send-push) ───────────────────────

async function getFirebaseAccessToken(sa: Record<string, string>): Promise<string> {
  const now     = Math.floor(Date.now() / 1000)
  const header  = toBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = toBase64Url(
    JSON.stringify({
      iss:   sa.client_email,
      sub:   sa.client_email,
      aud:   'https://oauth2.googleapis.com/token',
      iat:   now,
      exp:   now + 3600,
      scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
    }),
  )

  const signingInput = `${header}.${payload}`
  const signature    = await signRS256(signingInput, sa.private_key)
  const jwt          = `${signingInput}.${signature}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const { access_token } = await res.json()
  return access_token
}

async function signRS256(input: string, pemKey: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBuffer(pemKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(input))
  return bufToBase64Url(sig)
}

function pemToBuffer(pem: string): ArrayBuffer {
  const b64    = pem.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\r?\n/g, '')
  const binary = atob(b64)
  const buf    = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i)
  return buf.buffer
}

function toBase64Url(str: string): string {
  return btoa(unescape(encodeURIComponent(str))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

function bufToBase64Url(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf)
  let binary  = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}
