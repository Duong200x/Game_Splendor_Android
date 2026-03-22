const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const APP_ID = process.env.AGORA_APP_ID;
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE;

module.exports = (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { channelName, uid = 0 } = req.body || {};

  if (!channelName) {
    return res.status(400).json({ error: 'Missing channelName' });
  }

  if (!APP_ID || !APP_CERTIFICATE) {
    return res.status(500).json({
      error:
        'Missing Agora credentials. Set AGORA_APP_ID and AGORA_APP_CERTIFICATE in environment variables.',
    });
  }

  // Token expires after 1 hour (3600 seconds)
  const expirationTimeInSeconds = 3600;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID,
    APP_CERTIFICATE,
    channelName,
    parseInt(uid),
    RtcRole.PUBLISHER,
    privilegeExpiredTs
  );

  console.log(`Generated token for channel: ${channelName}, uid: ${uid}`);

  return res.status(200).json({
    token,
    channelName,
    uid: parseInt(uid),
    appId: APP_ID,
  });
};
