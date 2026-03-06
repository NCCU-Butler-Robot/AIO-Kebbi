# AIO-Kebbi 系統整合更新說明

## 完成的整合功能

### 1. 食物辨識 API 整合
- **位置**: `backend/chat/src/food_recognition/`
- **功能**: 整合您提供的 FoodRecognitionService.py 到 chat 服務中
- **API 端點**: `POST /api/food-recognition/`
- **特點**: 
  - 支援圖片上傳
  - 調用 https://food.bestweiwei.dpdns.org API
  - 錯誤處理，失敗時返回預設 URL

### 2. 新的 TTS 服務整合
- **位置**: `backend/chat/src/tts_service/`
- **功能**: 整合您的簡化版 TTS (使用 OpenAI TTS API)
- **特點**:
  - 替換原有的 gTTS
  - 異步處理，不阻塞主線程
  - 支援多種語音模型 (alloy, echo, fable, onyx, nova, shimmer)

### 3. Chat API 響應機制變更
- **變更**: chat API 現在直接返回語音檔案
- **響應格式**: 
  - **內容**: MP3 音頻檔案
  - **Headers 中的文字**:
    - `X-Response-Text`: 對話文字內容
    - `X-Message-Id`: 訊息 ID
    - `X-Conversation-Id`: 對話 ID
    - `X-Recipient-User-Id`: 接收用戶 ID
    - `X-Source-Installation-Id`: 來源裝置 ID

## 配置更新

### 環境變數 (需要在 .env 中設定)
```env
# TTS Service Configuration (OpenAI)
OPENAI_API_KEY=your_openai_api_key_here
TTS_MODEL=tts-1
VOICE_MODEL=alloy

# Food Recognition Service Configuration
FOOD_API_URL=https://food.bestweiwei.dpdns.org
```

### Docker 服務變更
- **移除**: 獨立的 TTS 服務 (已整合到 chat 中)
- **保留**: 食物辨識使用外部 API，無需單獨容器
- **更新**: chat 服務新增相關依賴

### Nginx 路由更新
- **新增**: `/api/food-recognition/` 路由指向 chat 服務
- **移除**: 原本註解的 food_detect_backend upstream
- **優化**: 支援大檔案上傳 (50MB)

## API 使用方式

### Chat API
```bash
curl -X POST "http://localhost:8100/api/chat/" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -H "X-Installation-Id: <device-id>" \
  -d '{"prompt": "Hello"}'
```
**回應**: MP3 檔案，文字在 headers 中

### 食物辨識 API  
```bash
curl -X POST "http://localhost:8100/api/food-recognition/" \
  -H "Authorization: Bearer <token>" \
  -H "X-Installation-Id: <device-id>" \
  -F "file=@food_image.jpg"
```
**回應**: JSON 格式的食譜 URL

## 注意事項

1. **依賴新增**: chat 服務新增了 openai, httpx, python-multipart 依賴
2. **API Key**: 需要有效的 OpenAI API Key 才能使用 TTS 功能
3. **檔案大小**: 食物辨識支援最大 50MB 的圖片檔案
4. **向後相容**: 如果 TTS 失敗，會降級到 JSON 響應
5. **Redis 整合**: 保留了原有的 Redis 事件發布機制

## 測試建議

1. 確保 OPENAI_API_KEY 環境變數已設定
2. 測試 chat API 是否正確返回音頻檔案
3. 測試食物辨識 API 是否能正確處理圖片
4. 檢查 headers 中的文字內容是否正確傳遞