const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const { user_id, title, body, data } = await req.json()

  if (!user_id || !title || !body) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: user_id, title, body' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)

  // 1. Obtain Firebase OAuth2 access token (used for both Firestore + FCM)
  const accessToken = await getFirebaseAccessToken(serviceAccount)

  // 2. Read FCM token from Firestore users/{user_id}.fcmToken
  const fcmToken = await getFcmTokenFromFirestore(serviceAccount.project_id, user_id, accessToken)

  if (!fcmToken) {
    return new Response(
      JSON.stringify({ error: 'FCM token not found for user', user_id }),
      { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  // 3. Send FCM push notification via HTTP v1 API
  const fcmRes = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          android: {
            priority: 'high',
            notification: {
              channel_id: 'bus_channel',
              priority: 'high',
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: {
              aps: {
                alert: { title, body },
                sound: 'default',
                'content-available': 1,
              },
            },
          },
          data: data ?? {},
        },
      }),
    },
  )

  const fcmResult = await fcmRes.json()

  if (!fcmRes.ok) {
    console.error('FCM send failed:', JSON.stringify(fcmResult))
    return new Response(
      JSON.stringify({ error: 'FCM delivery failed', details: fcmResult }),
      { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  return new Response(
    JSON.stringify({ success: true, message_id: fcmResult.name }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  )
})

// ── Read FCM token from Firestore ────────────────────────────────────────────

async function getFcmTokenFromFirestore(
  projectId: string,
  userId: string,
  accessToken: string,
): Promise<string | null> {
  try {
    const res = await fetch(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${userId}`,
      { headers: { 'Authorization': `Bearer ${accessToken}` } },
    )
    if (!res.ok) return null
    const doc = await res.json()
    return doc.fields?.fcmToken?.stringValue ?? null
  } catch {
    return null
  }
}

// ── Firebase OAuth2 via RS256 JWT Bearer ─────────────────────────────────────

async function getFirebaseAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = toBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = toBase64Url(
    JSON.stringify({
      iss: sa.client_email,
      sub: sa.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
      scope: [
        'https://www.googleapis.com/auth/firebase.messaging',
        'https://www.googleapis.com/auth/datastore',
      ].join(' '),
    }),
  )

  const signingInput = `${header}.${payload}`
  const signature = await signRS256(signingInput, sa.private_key)
  const jwt = `${signingInput}.${signature}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
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
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(input),
  )
  return bufToBase64Url(sig)
}

function pemToBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\r?\n/g, '')
  const binary = atob(b64)
  const buf = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i)
  return buf.buffer
}

function toBase64Url(str: string): string {
  return btoa(unescape(encodeURIComponent(str)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

function bufToBase64Url(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf)
  let binary = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}
