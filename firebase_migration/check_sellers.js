
const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const credentials = require(
  process.env.GOOGLE_APPLICATION_CREDENTIALS
);

const app = initializeApp({
  credential: cert(credentials),
  projectId: credentials.project_id,
});

const db = getFirestore(app);

const sellers = [
  {
    name: "Blush Avenue",
    oldId: "3phbyfUZGqaTCzgmPpKj",
    newId: "Y1AnDvV5jCMTiEDxHhGzIOKEWt33",
  },
  {
    name: "Urban Thread",
    oldId: "BFaHpCljL6UKlcrZLoER",
    newId: "Uq1U84MuwocNNga4MWNXJVi1gWT2",
  },
];

async function inspectDocument(ref) {
  const snapshot = await ref.get();

  if (!snapshot.exists) {
    console.log("  Document: NOT FOUND");
    return;
  }

  console.log("  Document: EXISTS");
  console.log("  Fields:", Object.keys(snapshot.data()));

  const subcollections = await ref.listCollections();

  for (const collection of subcollections) {
    const docs = await collection.get();

    console.log(
      `  Subcollection "${collection.id}": ${docs.size} documents`
    );

    for (const doc of docs.docs) {
      console.log("    -", doc.id);
    }
  }
}

async function check() {
  try {
    console.log("Firebase project:", credentials.project_id);

    for (const seller of sellers) {
      console.log("\n==============================");
      console.log(seller.name);

      console.log("\nOLD DOCUMENT:");
      await inspectDocument(
        db.collection("Users").doc(seller.oldId)
      );

      console.log("\nAUTH UID DOCUMENT:");
      await inspectDocument(
        db.collection("Users").doc(seller.newId)
      );
    }
  } catch (error) {
    console.error("Diagnostic error:", error);
  } finally {
    await app.delete();
  }
}

check();
