const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// 🔐 Callable function to set userType as a custom claim
exports.setUserClaims = functions.https.onCall(async (data, context) => {
  const { uid, userType } = data;

  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  if (!uid || !userType) {
    throw new functions.https.HttpsError("invalid-argument", "Missing uid or userType.");
  }

  await admin.auth().setCustomUserClaims(uid, { userType });
  return { message: `Set userType '${userType}' for user ${uid}` };
});
