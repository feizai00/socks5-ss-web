const express = require('express');
const router = express.Router();
const controller = require('../controllers/customerController');
const verifyToken = require('../middleware/auth');

router.get('/', verifyToken, controller.getAllCustomers);
router.post('/', verifyToken, controller.createCustomer);
router.put('/:id', verifyToken, controller.updateCustomer);
router.delete('/:id', verifyToken, controller.deleteCustomer);

module.exports = router;
