const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.recordMapView = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Wymagane uwierzytelnienie');
  }

  const { mapId } = data;

  if (!mapId) {
    throw new functions.https.HttpsError('invalid-argument', 'Brak ID mapy');
  }

  try {
    await admin.firestore().collection('satellite_maps').doc(mapId).update({
      'generatedMetadata.viewCount': admin.firestore.FieldValue.increment(1),
      'generatedMetadata.lastViewed': admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, message: 'Wyświetlenie zarejestrowane' };
  } catch (error) {
    console.error('Błąd aktualizacji licznika:', error);
    throw new functions.https.HttpsError('internal', 'Błąd serwera');
  }
});
