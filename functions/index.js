const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { AggregateField } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// ─── onTripEnd ─────────────────────────────────────────────────────────────
// Firestore trigger: when a bus document's driverStatus changes FROM 'on_trip',
// batch-cancel all waiting bookings and batch-complete all boarded bookings.
// This ensures booking lifecycle transitions happen even if the voyageur_app
// is killed or the device loses connectivity.
exports.onTripEnd = onDocumentUpdated(
  { document: 'buses/{busId}', region: 'us-central1' },
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // Only act when driverStatus changes FROM 'on_trip' to something else
    if (beforeData.driverStatus !== 'on_trip' || afterData.driverStatus === 'on_trip') {
      return null;
    }

    const busId = event.params.busId;
    console.log(`Trip ended for bus ${busId}: ${beforeData.driverStatus} → ${afterData.driverStatus}`);

    const bookingsRef = db.collection('bookings');
    const batch = db.batch();
    let updateCount = 0;

    // Cancel all waiting/pending/confirmed bookings for this bus
    const waitingSnap = await bookingsRef
      .where('busId', '==', busId)
      .where('status', 'in', ['waiting', 'pending', 'confirmed'])
      .get();

    for (const doc of waitingSnap.docs) {
      batch.update(doc.ref, { status: 'cancelled' });
      updateCount++;
    }

    // Complete all boarded bookings for this bus
    const boardedSnap = await bookingsRef
      .where('busId', '==', busId)
      .where('status', '==', 'boarded')
      .get();

    for (const doc of boardedSnap.docs) {
      batch.update(doc.ref, { status: 'completed' });
      updateCount++;
    }

    if (updateCount > 0) {
      await batch.commit();
      console.log(`Updated ${updateCount} bookings for bus ${busId} (cancelled waiting, completed boarded)`);
    } else {
      console.log(`No active bookings found for bus ${busId}`);
    }

    return null;
  }
);

// ─── submitPaymentRequest ──────────────────────────────────────────────────
// Called by transport_app owners after uploading a payment receipt to Supabase.
// Creates a payment_requests document and sets subscriptionStatus to
// 'pending_verification' so the admin review queue picks it up.
// Rate-limited to 3 submissions per 24 hours per user.
exports.submitPaymentRequest = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const uid = request.auth.uid;
  const { planId, receiptUrl, refNumber } = request.data;

  if (!planId || typeof planId !== 'string') {
    throw new HttpsError('invalid-argument', 'planId is required.');
  }
  if (!receiptUrl || typeof receiptUrl !== 'string') {
    throw new HttpsError('invalid-argument', 'receiptUrl is required.');
  }
  if (!refNumber || typeof refNumber !== 'string') {
    throw new HttpsError('invalid-argument', 'refNumber is required.');
  }

  // Rate limiting: max 3 submissions per 24 hours
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const recentSnap = await db.collection('payment_requests')
    .where('ownerId', '==', uid)
    .where('createdAt', '>', admin.firestore.Timestamp.fromDate(cutoff))
    .get();

  if (recentSnap.size >= 3) {
    throw new HttpsError('resource-exhausted', 'Too many payment requests in the last 24 hours.');
  }

  const now = admin.firestore.Timestamp.now();
  const reqRef = db.collection('payment_requests').doc();

  // Atomic: create request + update user status in one batch
  const batch = db.batch();

  batch.set(reqRef, {
    id: reqRef.id,
    ownerId: uid,
    planId,
    receiptUrl,
    refNumber,
    status: 'pending',
    createdAt: now,
    updatedAt: now,
  });

  batch.update(db.collection('users').doc(uid), {
    subscriptionStatus: 'pending_verification',
    subscription: planId,
    updatedAt: now,
  });

  await batch.commit();

  return { success: true, requestId: reqRef.id };
});

// ─── approvePaymentRequest ─────────────────────────────────────────────────
// Admin-only callable: marks a pending payment request as approved,
// activates the subscription, and extends the expiry by 30 days.
exports.approvePaymentRequest = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const callerDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin only.');
  }

  const { uid, requestId } = request.data;
  if (!uid) throw new HttpsError('invalid-argument', 'uid is required.');

  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
  );

  const batch = db.batch();

  batch.update(db.collection('users').doc(uid), {
    subscriptionStatus: 'active',
    subscriptionExpiresAt: expiresAt,
    updatedAt: now,
  });

  if (requestId) {
    batch.update(db.collection('payment_requests').doc(requestId), {
      status: 'approved',
      updatedAt: now,
    });
  } else {
    // Fall back: find the most recent pending request for this user
    const pending = await db.collection('payment_requests')
      .where('ownerId', '==', uid)
      .where('status', '==', 'pending')
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();
    if (!pending.empty) {
      batch.update(pending.docs[0].ref, { status: 'approved', updatedAt: now });
    }
  }

  await batch.commit();
  return { success: true };
});

// ─── rejectPaymentRequest ──────────────────────────────────────────────────
// Admin-only callable: rejects a pending payment request and notifies the user.
exports.rejectPaymentRequest = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const callerDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin only.');
  }

  const { uid, requestId, reason } = request.data;
  if (!uid) throw new HttpsError('invalid-argument', 'uid is required.');

  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();

  batch.update(db.collection('users').doc(uid), {
    subscriptionStatus: 'rejected',
    rejectionReason: reason || '',
    updatedAt: now,
  });

  if (requestId) {
    batch.update(db.collection('payment_requests').doc(requestId), {
      status: 'rejected',
      rejectionReason: reason || '',
      updatedAt: now,
    });
  } else {
    const pending = await db.collection('payment_requests')
      .where('ownerId', '==', uid)
      .where('status', '==', 'pending')
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();
    if (!pending.empty) {
      batch.update(pending.docs[0].ref, {
        status: 'rejected',
        rejectionReason: reason || '',
        updatedAt: now,
      });
    }
  }

  await batch.commit();
  return { success: true };
});

// ─── sendDailyAlerts ──────────────────────────────────────────────────────────
// Runs every day at 08:00 Algeria time. For every active owner, checks each
// bus and sends FCM push notifications for assurance expiry, upcoming salary
// payments, and vidange thresholds — identical logic to the Flutter-side
// AlertNotificationService.checkAndNotify(), but works when the app is killed.
const ASSURANCE_THRESHOLD_DAYS = 15;
const SALARY_THRESHOLD_DAYS    = 3;
const VIDANGE_INTERVAL_KM      = 10000;
const VIDANGE_WARN_KM          = 1000;
const VIDANGE_URGENT_KM        = 500;

exports.sendDailyAlerts = onSchedule(
  { schedule: '0 10 * * *', timeZone: 'Africa/Algiers', region: 'us-central1' },
  async () => {
    const now      = new Date();
    const todayKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

    const ownersSnap = await db.collection('users')
      .where('role', '==', 'owner')
      .where('subscriptionStatus', '==', 'active')
      .get();

    const tasks = [];

    for (const ownerDoc of ownersSnap.docs) {
      const owner    = ownerDoc.data();
      const uid      = ownerDoc.id;
      const fcmToken = owner.fcmToken;
      if (!fcmToken) continue;

      const busesSnap = await db.collection('buses')
        .where('ownerId', '==', uid)
        .where('isActive', '==', true)
        .get();

      for (const busDoc of busesSnap.docs) {
        const bus     = busDoc.data();
        const busId   = bus.busId || busDoc.id;
        const busName = (bus.busName || '').trim() || `Bus ${bus.busNumber || busId}`;

        // ── Assurance (notify exactly at threshold day) ──────────────────────
        if (bus.assuranceEndDate) {
          const daysLeft = Math.ceil(
            (bus.assuranceEndDate.toDate() - now) / 86400000
          );
          if (daysLeft === ASSURANCE_THRESHOLD_DAYS) {
            tasks.push(_sendAlertIfNew({
              uid, busId, todayKey, alertType: 'assurance', fcmToken,
              title: `Assurance — ${busName}`,
              body:  `L'assurance expire dans ${ASSURANCE_THRESHOLD_DAYS} jours.`,
            }));
          }
        }

        // ── Salary (notify exactly at threshold day) ──────────────────────────
        const hasDriver    = typeof bus.driverId === 'string' && bus.driverId.length > 0;
        const hasRecipient = typeof bus.recipient === 'number' && bus.recipient > 0;
        if (hasDriver || hasRecipient) {
          const positions = [];
          if (hasDriver)    positions.push('Chauffeur');
          if (hasRecipient) positions.push('Receveur');

          let nextSalary = new Date(now.getFullYear(), now.getMonth() + 1, 1);
          if (bus.lastSalaryDate) {
            const daysSinceLast = (now - bus.lastSalaryDate.toDate()) / 86400000;
            if (daysSinceLast < 20) {
              nextSalary = new Date(now.getFullYear(), now.getMonth() + 2, 1);
            }
          }
          const daysToSalary = Math.ceil((nextSalary - now) / 86400000);
          if (daysToSalary === SALARY_THRESHOLD_DAYS) {
            tasks.push(_sendAlertIfNew({
              uid, busId, todayKey, alertType: 'salary', fcmToken,
              title: `Salaires — ${busName}`,
              body:  `Les salaires (${positions.join(' & ')}) sont dans ${SALARY_THRESHOLD_DAYS} jours.`,
            }));
          }
        }

        // ── Vidange (range-based, daily dedup prevents spam) ─────────────────
        let tripQuery = db.collection('trips').where('busId', '==', busId);
        if (bus.lastVidangeDate) {
          tripQuery = tripQuery.where('timestamp', '>', bus.lastVidangeDate);
        }
        let traveled = 0;
        try {
          const agg = await tripQuery
            .aggregate({ traveled: AggregateField.sum('distanceKm') })
            .get();
          traveled = agg.data().traveled ?? 0;
        } catch (_) {}

        const kmRemaining = VIDANGE_INTERVAL_KM - traveled;

        if (kmRemaining <= VIDANGE_URGENT_KM && kmRemaining > 0) {
          tasks.push(_sendAlertIfNew({
            uid, busId, todayKey, alertType: 'vidange_urgent', fcmToken,
            title: `Vidange urgente — ${busName}`,
            body:  `Seulement ${Math.round(kmRemaining)} km avant la prochaine vidange !`,
          }));
        } else if (kmRemaining <= VIDANGE_WARN_KM) {
          tasks.push(_sendAlertIfNew({
            uid, busId, todayKey, alertType: 'vidange_warn', fcmToken,
            title: `Vidange — ${busName}`,
            body:  `La vidange est dans ${Math.round(kmRemaining)} km.`,
          }));
        }
      }
    }

    await Promise.allSettled(tasks);
  }
);

// Sends an FCM push only if this (uid, busId, alertType, day) hasn't been sent yet.
async function _sendAlertIfNew({ uid, busId, todayKey, alertType, fcmToken, title, body }) {
  const logRef = db.collection('alert_logs').doc(
    `${uid}_${busId}_${alertType}_${todayKey}`
  );
  const already = await logRef.get();
  if (already.exists) return;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: {
        priority: 'high',
        notification: { channelId: 'bus_channel' },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { alert: { title, body }, sound: 'default' } },
      },
    });
    await logRef.set({
      sentAt: admin.firestore.Timestamp.now(),
      alertType, busId, uid,
    });
  } catch (err) {
    console.error(`[sendDailyAlerts] ${alertType} for bus ${busId}:`, err.message);

    // Always write the log on failure so the next run's existence-check
    // returns true and does not retry, preventing a spam loop.
    await logRef.set({
      sentAt: admin.firestore.Timestamp.now(),
      alertType, busId, uid,
      failed: true,
      errorCode: err.code || 'unknown',
    }).catch((e) => console.error('[sendDailyAlerts] failed to write error log:', e.message));

    // For unrecoverable token errors, delete the stale token so future
    // scheduled runs skip this owner entirely instead of hitting FCM again.
    const INVALID_TOKEN_CODES = [
      'messaging/invalid-registration-token',
      'messaging/registration-token-not-registered',
    ];
    if (INVALID_TOKEN_CODES.includes(err.code)) {
      await db.collection('users').doc(uid)
        .update({ fcmToken: admin.firestore.FieldValue.delete() })
        .catch((e) => console.error('[sendDailyAlerts] failed to clear stale token:', e.message));
    }
  }
}
