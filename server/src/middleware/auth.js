const authService = require('../services/authService');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: '인증 토큰이 필요합니다.' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = authService.verifyToken(token);

    if (!decoded) {
      return res.status(401).json({ message: '유효하지 않은 토큰입니다.' });
    }

    req.userId = decoded.id;
    next();
  } catch (error) {
    console.error('인증 미들웨어 오류:', error);
    res.status(401).json({ message: '인증에 실패했습니다.' });
  }
};

module.exports = authMiddleware;
