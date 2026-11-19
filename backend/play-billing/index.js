import { initializeApp } from 'firebase-admin/app';
import { getAppCheck } from 'firebase-admin/app-check';
import { defineString } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';
import { GoogleAuth } from 'google-auth-library';
import { verifyPurchase } from './verification.js';

initializeApp();

const androidAppId = defineString('INKURI_FIREBASE_ANDROID_APP_ID');
const serviceAccount = defineString('INKURI_PLAY_SERVICE_ACCOUNT');
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/androidpublisher'],
});

export const verifyPlayPurchase = onRequest(
  { region: 'asia-northeast1', maxInstances: 3, timeoutSeconds: 25, serviceAccount },
  async (req, res) => {
    res.set('Cache-Control', 'no-store');
    if (req.method !== 'POST') {
      res.set('Allow', 'POST').sendStatus(405);
      return;
    }
    const appCheckToken = req.get('X-Firebase-AppCheck');
    const purchaseToken = req.body?.purchaseToken;
    if (!appCheckToken) {
      res.sendStatus(401);
      return;
    }
    if (typeof purchaseToken !== 'string' ||
        !/^[A-Za-z0-9._~+/-]{16,4096}$/.test(purchaseToken)) {
      res.sendStatus(400);
      return;
    }
    try {
      const attestation = await getAppCheck().verifyToken(appCheckToken);
      if (attestation.appId !== androidAppId.value()) {
        res.sendStatus(403);
        return;
      }
    } catch {
      res.sendStatus(401);
      return;
    }
    try {
      const client = await auth.getClient();
      res.json({ entitled: await verifyPurchase(client, purchaseToken) });
    } catch {
      // Do not log tokens or upstream payloads.
      res.sendStatus(503);
    }
  },
);
