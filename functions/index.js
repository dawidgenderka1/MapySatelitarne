const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({origin: true});

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

exports.getImageProxy = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    try {
      const imageUrl = req.query.url;
      
      if (!imageUrl) {
        return res.status(400).send('Missing url parameter');
      }

      const bucket = admin.storage().bucket();
      const filePath = decodeURIComponent(imageUrl.split('/o/')[1].split('?')[0]);
      const file = bucket.file(filePath);

      const [exists] = await file.exists();
      if (!exists) {
        return res.status(404).send('File not found');
      }

      const readStream = file.createReadStream();
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Methods', 'GET');
      res.set('Content-Type', 'image/jpeg');
      res.set('Cache-Control', 'public, max-age=3600');

      readStream.pipe(res);
    } catch (error) {
      console.error('Error proxying image:', error);
      res.status(500).send('Error loading image');
    }
  });
});
