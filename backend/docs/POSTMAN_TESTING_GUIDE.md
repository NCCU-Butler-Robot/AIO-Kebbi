# AIO-Kebbi Postman 完整測試指南

本指南將帶您完成從用戶註冊到測試所有 API 功能的完整流程。

## 前置準備

### 1. 環境設置
- 確保系統運行在 `http://localhost:8100`
- 確保已設置所需的環境變數，特別是 `OPENAI_API_KEY`

### 2. Postman 變數設置
在 Postman 中建立環境變數：
```
baseUrl: http://localhost:8100
accessToken: (將在登入後自動設置)
refreshToken: (將在登入後自動設置)
```

---

## 第一步：用戶註冊

### API: 註冊新用戶

**方法**: `POST`  
**URL**: `{{baseUrl}}/auth/register`

> ⚠️ **Postman 設置說明**:
> 1. 在左上方下拉選單選擇 "POST"
> 2. 在 URL 欄位輸入: `{{baseUrl}}/auth/register`
> 3. 不要在 URL 欄位輸入 "POST" 字樣

**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "username": "testuser2026",
  "email": "testuser2026@example.com",
  "phone_number": "0987654321",
  "name": "Test User 2026",
  "password": "securepassword123"
}
```

**期望響應:**
```json
{
  "uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "username": "testuser2026",
  "email": "testuser2026@example.com",
  "phone_number": "0987654321",
  "name": "Test User 2026"
}
```

---

## 第二步：用戶登入

### API: 用戶登入

**方法**: `POST`  
**URL**: `{{baseUrl}}/auth/login`

> ⚠️ **Postman 設置說明**:
> 1. 方法選擇: "POST"
> 2. URL 欄位: `{{baseUrl}}/auth/login`
> 3. Headers 標籤中添加: `Content-Type: application/x-www-form-urlencoded`
> 4. Body 標籤中選擇 "x-www-form-urlencoded"

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
```

**Body (x-www-form-urlencoded):**

在 Postman 的 Body 標籤中選擇 "x-www-form-urlencoded"，然後添加以下 key-value 對：

| Key | Value |
|-----|-------|
| username | testuser2026 |
| password | securepassword123 |

> ⚠️ **重要**: 不要在 Value 欄位中添加引號!

**期望響應:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1Ni...",
  "token_type": "bearer"
}
```

**Postman Script (Tests 標籤):**
```javascript
// 自動保存 access token
if (pm.response.code === 200) {
    const responseJson = pm.response.json();
    pm.environment.set("accessToken", responseJson.access_token);
    console.log("Access token saved:", responseJson.access_token);
}

// 自動保存 refresh token (從 cookie)
const cookies = pm.cookies.all();
cookies.forEach(cookie => {
    if (cookie.name === 'refresh_token') {
        pm.environment.set("refreshToken", cookie.value);
        console.log("Refresh token saved from cookie");
    }
});
```

---

## 第三步：驗證身份

### API: 獲取當前用戶狀態

**方法**: `GET`  
**URL**: `{{baseUrl}}/auth/status`

**Headers:**
```
Authorization: Bearer {{accessToken}}
```

**期望響應:**
```json
{
  "uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "username": "testuser2026",
  "email": "testuser2026@example.com",
  "phone_number": "0987654321",
  "name": "Test User 2026"
}
```

---

## 第四步：測試 Chat API (新功能)

### API: 對話聊天 (返回語音檔案)

**方法**: `POST`  
**URL**: `{{baseUrl}}/api/chat/`

**Headers:**
```
Authorization: Bearer {{accessToken}}
Content-Type: application/json
X-Installation-Id: device001
```

**Body (JSON):**
```json
{
  "prompt": "Hello, how are you today?"
}
```

**期望響應:**
- **Content-Type**: `audio/mpeg`
- **Content**: MP3 音頻檔案
- **自定義 Headers**:
  - `X-Response-Text`: 對話文字內容
  - `X-Message-Id`: 訊息 ID
  - `X-Conversation-Id`: 對話 ID
  - `X-Recipient-User-Id`: 用戶 ID
  - `X-Source-Installation-Id`: 裝置 ID

**Postman Script (Tests 標籤):**
```javascript
// 檢查響應是否為音頻檔案
pm.test("Response is audio file", function () {
    pm.expect(pm.response.headers.get("Content-Type")).to.include("audio/mpeg");
});

// 檢查自定義 headers
pm.test("Custom headers present", function () {
    pm.expect(pm.response.headers.get("X-Response-Text")).to.not.be.null;
    pm.expect(pm.response.headers.get("X-Message-Id")).to.not.be.null;
    pm.expect(pm.response.headers.get("X-Conversation-Id")).to.not.be.null;
});

// 顯示文字內容
console.log("Response Text:", pm.response.headers.get("X-Response-Text"));
```

---

## 第五步：測試 Anti-Fraud API (新功能)

### API: 反詐騙對話 (返回語音檔案)

**方法**: `POST`  
**URL**: `{{baseUrl}}/api/fraud/`

> 🎯 **功能說明**:
> - 此 API 專門設計用於反詐騙場景
> - AI 助理 "Sarah" 會扮演一位略顯緊張但願意配合的中年女性
> - 目標是引導詐騙犯透露更多資訊，延長通話時間
> - 支援英語對話，針對外國詐騙犯

**Headers:**
```
Authorization: Bearer {{accessToken}}
Content-Type: application/json
X-Installation-Id: device001
```

**Body (JSON):**
```json
{
  "prompt": "Hello, this is customer service from your bank. We've detected some suspicious activity on your account."
}
```

**其他測試案例:**

**Tech Support詐騙:**
```json
{
  "prompt": "This is Microsoft technical support. Your computer is infected with viruses and we need remote access to fix it."
}
```

**IRS/稅務詐騙:**
```json
{
  "prompt": "This is the Internal Revenue Service. You owe back taxes and must pay immediately or face arrest."
}
```

**樂透詐騙:**
```json
{
  "prompt": "Congratulations! You've won $1 million in our lottery. To claim your prize, we need to verify your information."
}
```

**期望響應:**
- **Content-Type**: `audio/mpeg`
- **Content**: MP3 音頻檔案
- **自定義 Headers**:
  - `X-Response-Text`: 對話文字內容 (英語)
  - `X-Message-Id`: 訊息 ID
  - `X-Conversation-Id`: 對話 ID
  - `X-Recipient-User-Id`: 用戶 ID
  - `X-Source-Installation-Id`: 裝置 ID
  - `X-Service-Type`: anti-fraud

**Postman Script (Tests 標籤):**
```javascript
// 檢查響應是否為音頻檔案
pm.test("Response is audio file", function () {
    pm.expect(pm.response.headers.get("Content-Type")).to.include("audio/mpeg");
});

// 檢查自定義 headers
pm.test("Anti-fraud headers present", function () {
    pm.expect(pm.response.headers.get("X-Response-Text")).to.not.be.null;
    pm.expect(pm.response.headers.get("X-Message-Id")).to.not.be.null;
    pm.expect(pm.response.headers.get("X-Conversation-Id")).to.not.be.null;
    pm.expect(pm.response.headers.get("X-Service-Type")).to.equal("anti-fraud");
});

// 檢查Sarah的回應特徵
pm.test("Sarah's response characteristics", function () {
    const responseText = pm.response.headers.get("X-Response-Text");
    // 檢查是否包含困惑或要求澄清的語言
    const confusedPhrases = ["don't understand", "explain", "which", "what", "who", "confused"];
    const hasConfusedPhrase = confusedPhrases.some(phrase => 
        responseText.toLowerCase().includes(phrase)
    );
    pm.expect(hasConfusedPhrase).to.be.true;
});

// 顯示文字內容
console.log("Sarah's Response:", pm.response.headers.get("X-Response-Text"));
console.log("Service Type:", pm.response.headers.get("X-Service-Type"));
```

**預期行為特徵:**
Sarah應該表現出以下特徵：
- ✅ 聽起來困惑或需要澄清
- ✅ 詢問更多細節 ("Which bank?", "What do I need to do?")
- ✅ 不會立即同意或拒絕
- ✅ 使用簡單直接的語言
- ✅ 偶爾重複詐騙犯的話來確認

---

## 第六步：測試食物辨識 API (新功能)

### API: 食物辨識

**方法**: `POST`  
**URL**: `{{baseUrl}}/api/food-recognition/`

> ⚠️ **Postman 設置說明**:
> 1. 方法選擇: "POST"
> 2. URL 欄位: `{{baseUrl}}/api/food-recognition/`
> 3. **重要**: 必須設置 Authorization header
> 4. Body 選擇 "form-data" 類型

**Headers:**
```
Authorization: Bearer {{accessToken}}
X-Installation-Id: device001
```

> 🔑 **認證要求**: 
> - 必須先完成登入步驟獲取 access token
> - 確保 `{{accessToken}}` 變數已正確設置
> - 如果出現 401 錯誤，請檢查 token 是否有效或已過期

**Body (form-data):**

在 Postman 的 Body 標籤中：
1. 選擇 "form-data" 選項
2. 添加一個 key-value 對：
   - Key: `file` (類型選擇 "File")
   - Value: 選擇一個圖片檔案（例如 food_image.jpg）

> 📸 **支援的圖片格式**: JPG, JPEG, PNG, GIF (最大 50MB)

**期望響應:**
```json
{
  "detect_url": "https://food.bestweiwei.dpdns.org/recipe_detail?title=detected_food",
  "user_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "installation_id": "device001",
  "filename": "food_image.jpg"
}
```

**Postman Script (Tests 標籤):**
```javascript
// 檢查響應包含食譜 URL
pm.test("Food detection successful", function () {
    const responseJson = pm.response.json();
    pm.expect(responseJson.detect_url).to.not.be.null;
    pm.expect(responseJson.detect_url).to.include("food.bestweiwei.dpdns.org");
});

console.log("Detected food URL:", pm.response.json().detect_url);
```

> 🔧 **常見錯誤處理**:
> - **401 錯誤**: `"Unauthorized: Invalid or missing token"`
>   - 檢查是否已完成登入步驟
>   - 確認 Authorization header 格式: `Bearer {{accessToken}}`
>   - 驗證 accessToken 變數是否正確設置
> - **400 錯誤**: `"Only image files are allowed"`
>   - 確保上傳的是圖片檔案
>   - 檢查檔案格式是否支援 (JPG, PNG, GIF)

---

## 第七步：測試 Token 刷新

### API: 刷新 Access Token

**方法**: `POST`  
**URL**: `{{baseUrl}}/auth/refresh_token`

**Headers:**
```
Cookie: refresh_token={{refreshToken}}
```

**期望響應:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1Ni...",
  "token_type": "bearer"
}
```

**Postman Script (Tests 標籤):**
```javascript
// 更新 access token
if (pm.response.code === 200) {
    const responseJson = pm.response.json();
    pm.environment.set("accessToken", responseJson.access_token);
    console.log("Access token refreshed");
}
```

---

## 第八步：登出

### API: 用戶登出

**方法**: `POST`  
**URL**: `{{baseUrl}}/auth/logout`

**Headers:**
```
Cookie: refresh_token={{refreshToken}}
```

**期望響應:**
```json
{
  "message": "Successfully logged out"
}
```

---

## 錯誤處理測試

### 1. 測試無效 Token
重複執行任何需要認證的 API，但使用無效的 token：
```
Authorization: Bearer invalid_token
```
**期望錯誤響應:**
```json
{
    "status": "error", 
    "message": "Unauthorized: Invalid or missing token."
}
```

### 2. 測試缺少認證
嘗試不設置 Authorization header 調用受保護的 API：
**期望錯誤響應:**
```json
{
    "detail": "Not authenticated"
}
```

### 2. 測試 TTS 降級
如果沒有設置 `OPENAI_API_KEY`：

**Chat API** 應該降級到 JSON 響應：
```json
{
  "message": "Hello, how are you today?",
  "message_id": "xxx",
  "conversation_id": "xxx",
  "recipient_user_id": "xxx",
  "source_installation_id": "device001",
  "error": "TTS generation failed"
}
```

**Anti-Fraud API** 應該降級到 JSON 響應：
```json
{
  "message": "I don't understand, could you explain that again?",
  "message_id": "xxx",
  "conversation_id": "xxx", 
  "recipient_user_id": "xxx",
  "source_installation_id": "device001",
  "service_type": "anti-fraud",
  "error": "TTS generation failed"
}
```

### 3. 測試食物辨識錯誤處理
上傳非圖片檔案，應該返回 400 錯誤：
```json
{
  "detail": "Only image files are allowed."
}
```

---

## 完整測試流程 Checklist

- [ ] 1. 用戶註冊成功
- [ ] 2. 用戶登入並獲得 tokens
- [ ] 3. 驗證用戶身份
- [ ] 4. Chat API 返回音頻檔案
- [ ] 5. Anti-Fraud API 返回英語音頻檔案
- [ ] 6. Sarah 表現出反詐騙特徵 (困惑、要求澄清)
- [ ] 7. Headers 中包含正確的文字內容和服務類型
- [ ] 8. 食物辨識 API 處理圖片並返回 URL
- [ ] 9. Token 刷新機制正常
- [ ] 10. 登出清除 tokens
- [ ] 11. 錯誤處理機制正常

---

## 注意事項

1. **安裝 ID**: `X-Installation-Id` header 是必須的，代表用戶的裝置
2. **檔案大小**: 食物辨識支援最大 50MB 的圖片
3. **音頻格式**: Chat API 和 Anti-Fraud API 都返回 MP3 格式的音頻檔案
4. **語言差異**: 
   - Chat API: 中文對話 (管家風格)
   - Anti-Fraud API: 英語對話 (反詐騙策略)
5. **Cookie 管理**: Postman 會自動處理 refresh token cookie
6. **環境變數**: 確保已正確設置所有必要的環境變數，特別是 `OPENAI_API_KEY`
7. **服務識別**: Anti-Fraud API 會在 Headers 中返回 `X-Service-Type: anti-fraud`

## 疑難排解

### Postman 常見錯誤

#### 1. "Invalid protocol" 錯誤
**錯誤訊息**: `Error: Invalid protocol: post http:`
**解決方案**: 
- 在 Postman 的方法選擇器中選擇 "POST"（不要在 URL 欄位中輸入 "POST"）
- URL 欄位只輸入: `http://localhost:8100/auth/login`

#### 2. 登入 form-data 格式錯誤
**問題**: 在 x-www-form-urlencoded 中使用了引號
**解決方案**: 
- 在 Body → x-www-form-urlencoded 中
- Key: `username`, Value: `testuser2026` (不要引號)
- Key: `password`, Value: `securepassword123` (不要引號)

#### 3. Headers 設置錯誤
**常見問題**: 忘記設置 Content-Type
**解決方案**: 確保每個請求都有正確的 Headers:
- 登入: `Content-Type: application/x-www-form-urlencoded`
- Chat: `Content-Type: application/json`

#### 4. 404 Not Found 錯誤 
**錯誤訊息**: `404 Not Found` 來自 nginx
**可能原因**: 
- 服務沒有正確啟動
- nginx 認證配置問題
- 路由配置錯誤

**診斷步驟**:
```bash
# 檢查服務狀態
cd /home/fintech/projects/AIO-Kebbi/backend
docker compose ps

# 檢查 nginx 日誌
docker compose logs nginx --tail=10

# 檢查 chat 服務日誌
docker compose logs chat --tail=10

# 重新載入 nginx 配置
docker compose exec nginx nginx -s reload
```

**解決方案**: 確保所有服務正在運行，並且 nginx 配置正確

### API 相關錯誤

- **401 錯誤**: 檢查 Authorization header 格式是否正確
- **音頻檔案為空**: 檢查 OPENAI_API_KEY 是否設置正確
- **食物辨識失敗**: 檢查網路連接和圖片格式
- **Token 過期**: 使用 refresh token 端點更新 access token