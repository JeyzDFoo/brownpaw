// Receives flow alerts while Brownpaw isn't open, and opens the gauge
// when one is tapped. The config below is the public web app config from
// lib/firebase_options.dart.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB3Yk9Dsqllb_JHait3341pxurheSO_EJM',
  appId: '1:1047120968895:web:5ec959fd59373af4899a0a',
  messagingSenderId: '1047120968895',
  projectId: 'brownclaw',
  authDomain: 'brownclaw.firebaseapp.com',
  storageBucket: 'brownclaw.firebasestorage.app',
});

// Notifications with a `notification` payload are shown automatically;
// the Cloud Function sets webpush.fcm_options.link so a tap opens the gauge.
firebase.messaging();
