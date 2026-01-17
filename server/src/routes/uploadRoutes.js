const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// 업로드 디렉토리 생성
const uploadDir = path.join(__dirname, '../../uploads');
const chatImagesDir = path.join(uploadDir, 'chat');
const profileImagesDir = path.join(uploadDir, 'profiles');

[uploadDir, chatImagesDir, profileImagesDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Multer 설정
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const type = req.params.type || 'chat';
    const dir = type === 'profile' ? profileImagesDir : chatImagesDir;
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const filename = `${uuidv4()}${ext}`;
    cb(null, filename);
  },
});

const fileFilter = (req, file, cb) => {
  const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('지원하지 않는 파일 형식입니다.'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
});

// 채팅 이미지 업로드
router.post('/chat', authMiddleware, upload.single('image'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: '이미지가 없습니다.' });
    }

    const imageUrl = `/uploads/chat/${req.file.filename}`;
    console.log(`📷 채팅 이미지 업로드: ${req.userId} -> ${imageUrl}`);
    
    res.json({
      success: true,
      imageUrl,
      filename: req.file.filename,
    });
  } catch (error) {
    console.error('이미지 업로드 오류:', error);
    res.status(500).json({ error: '이미지 업로드 실패' });
  }
});

// 프로필 이미지 업로드
router.post('/profile', authMiddleware, upload.single('image'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: '이미지가 없습니다.' });
    }

    const imageUrl = `/uploads/profiles/${req.file.filename}`;
    console.log(`📷 프로필 이미지 업로드: ${req.userId} -> ${imageUrl}`);
    
    res.json({
      success: true,
      imageUrl,
      filename: req.file.filename,
    });
  } catch (error) {
    console.error('프로필 이미지 업로드 오류:', error);
    res.status(500).json({ error: '프로필 이미지 업로드 실패' });
  }
});

module.exports = router;
