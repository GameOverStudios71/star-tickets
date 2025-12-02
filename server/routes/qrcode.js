const express = require('express');
const router = express.Router();
const QRCode = require('qrcode');

module.exports = () => {
    // Generate QR Code for ticket
    router.get('/qrcode/:ticketId', async (req, res) => {
        const ticketId = req.params.ticketId;
        const trackingUrl = `${req.protocol}://${req.get('host')}/track.html?ticket=${ticketId}`;

        try {
            const qrCodeDataUrl = await QRCode.toDataURL(trackingUrl, {
                width: 300,
                margin: 2,
                color: {
                    dark: '#000000',
                    light: '#FFFFFF'
                }
            });
            res.json({ qrCode: qrCodeDataUrl, url: trackingUrl });
        } catch (err) {
            res.status(500).json({ error: 'Erro ao gerar QR Code' });
        }
    });

    return router;
};
