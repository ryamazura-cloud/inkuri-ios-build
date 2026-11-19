import assert from 'node:assert/strict';
import test from 'node:test';
import { verifyPurchase } from './verification.js';

function purchase(state = 'PURCHASED', acknowledged = true) {
  return {
    purchaseStateContext: { purchaseState: state },
    acknowledgementState: acknowledged
      ? 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
      : 'ACKNOWLEDGEMENT_STATE_PENDING',
    productLineItem: [{
      productId: 'inkuri_unlimited',
      productOfferDetails: {
        refundableQuantity: 1,
        consumptionState: 'CONSUMPTION_STATE_YET_TO_BE_CONSUMED',
      },
    }],
  };
}

test('only a matching purchased and unrefunded product grants access', async () => {
  const unrelated = purchase();
  unrelated.productLineItem[0].productId = 'other';
  const refunded = purchase();
  refunded.productLineItem[0].productOfferDetails.refundableQuantity = 0;
  for (const record of [purchase('CANCELLED'), purchase('PENDING'), unrelated, refunded]) {
    assert.equal(await verifyPurchase({ request: async () => ({ data: record }) }, 'token'), false);
  }
  assert.equal(await verifyPurchase({ request: async () => ({ data: purchase() }) }, 'token'), true);
});

test('pending acknowledgement is confirmed before granting access', async () => {
  const requests = [];
  const client = {
    async request(request) {
      requests.push(request);
      return { data: purchase('PURCHASED', false) };
    },
  };
  assert.equal(await verifyPurchase(client, 'token'), true);
  assert.equal(requests.length, 2);
  assert.match(requests[0].url, /\/productsv2\/tokens\/token$/);
  assert.equal(requests[1].method, 'POST');
  assert.match(requests[1].url, /\/products\/inkuri_unlimited\/tokens\/token:acknowledge$/);
});

test('an upstream outage never grants access', async () => {
  const outage = Object.assign(new Error('upstream unavailable'), { response: { status: 503 } });
  await assert.rejects(verifyPurchase({ request: async () => { throw outage; } }, 'token'), outage);
});
