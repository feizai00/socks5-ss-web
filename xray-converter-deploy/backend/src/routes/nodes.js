const express = require('express');
const router = express.Router();
const controller = require('../controllers/nodeController');
const verifyToken = require('../middleware/auth');

router.get('/', verifyToken, controller.getAllNodes);
router.post('/', verifyToken, controller.createNode);
router.put('/:id', verifyToken, controller.updateNode);
router.delete('/:id', verifyToken, controller.deleteNode);

module.exports = router;
