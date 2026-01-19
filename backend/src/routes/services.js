const express = require('express');
const router = express.Router();
const controller = require('../controllers/serviceController');
const verifyToken = require('../middleware/auth');

router.get('/', verifyToken, controller.getAllServices);
router.post('/', verifyToken, controller.createService);
router.delete('/:id', verifyToken, controller.deleteService);
router.post('/:id/toggle', verifyToken, controller.toggleService);

module.exports = router;
