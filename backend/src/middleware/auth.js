const jwt = require('jsonwebtoken');

const verifyToken = (req, res, next) => {
    const token = req.body.token || req.query.token || req.headers['x-access-token'] || req.headers['authorization'];

    if (!token) {
        return res.status(403).send("需要认证令牌");
    }

    try {
        const bearer = token.split(' ');
        const bearerToken = bearer[1] || token;
        
        const decoded = jwt.verify(bearerToken, process.env.JWT_SECRET || 'default_secret_key');
        req.user = decoded;
    } catch (err) {
        return res.status(401).send("无效的令牌");
    }
    return next();
};

module.exports = verifyToken;
