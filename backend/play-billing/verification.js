const productId = 'inkuri_unlimited';
const api = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/biz.wisemap.encre';

export async function verifyPurchase(client, token) {
  const path = encodeURIComponent(token);
  const checkUrl = `${api}/purchases/productsv2/tokens/${path}`;
  const get = () => client.request({ url: checkUrl, timeout: 5000 });
  let purchase;
  try {
    ({ data: purchase } = await get());
  } catch (error) {
    if ([404, 410].includes(error.response?.status)) return false;
    throw error;
  }
  const eligible = (record) =>
    record.purchaseStateContext?.purchaseState === 'PURCHASED' &&
    record.productLineItem?.some((item) =>
      item.productId === productId &&
      item.productOfferDetails?.consumptionState === 'CONSUMPTION_STATE_YET_TO_BE_CONSUMED' &&
      item.productOfferDetails?.refundableQuantity > 0 &&
      !item.productOfferDetails?.rentOfferDetails);
  if (!eligible(purchase)) return false;
  if (purchase.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED') {
    return true;
  }
  if (purchase.acknowledgementState !== 'ACKNOWLEDGEMENT_STATE_PENDING') {
    throw new Error('Unexpected acknowledgement status');
  }
  try {
    await client.request({
      method: 'POST',
      url: `${api}/purchases/products/${productId}/tokens/${path}:acknowledge`,
      data: {},
      timeout: 5000,
    });
  } catch (error) {
    // Another restore may have acknowledged the same purchase concurrently.
    const { data } = await get();
    if (!eligible(data)) return false;
    if (data.acknowledgementState !== 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED') {
      throw error;
    }
  }
  return true;
}
