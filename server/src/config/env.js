// 환경 변수 설정 파일
// 실제 배포시에는 환경 변수로 관리하세요

module.exports = {
  PORT: process.env.PORT || 3000,
  NODE_ENV: process.env.NODE_ENV || 'development',
  MONGODB_URI: process.env.MONGODB_URI || 'mongodb+srv://Chatapp:DVHZVleomFE2o8jH@chatapp.k2mig.mongodb.net/randomchat?retryWrites=true&w=majority',
  JWT_SECRET: process.env.JWT_SECRET || 'your_jwt_secret_key_change_in_production',
  KAKAO_REST_API_KEY: process.env.KAKAO_REST_API_KEY || 'your_kakao_rest_api_key',
  
};
