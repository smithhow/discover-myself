# Discover‑Myself – 完全离线自我评测平台

## 1. 项目概述
- **目标**：在用户手机/电脑上完成完整的自我评测（人格、智商、情商、兴趣、天赋等），并通过游戏化反馈、积分、徽章、抽奖等机制激励用户完成整个流程。<br>
- **无后端**：所有判定、数据、模型、奖品等均保存在本地；同一设备上可完整离线使用。<br>
- **技术栈**：React Native 或 Flutter（原生跨平台），或 PWA（Web），四种视图：
  * **测评**：多选/单选/问答抵 
  * **结果**：星盘、成长树、报告导出
  * **奖励**：积分/徽章/抽奖（本地随机）
  * **成长建议**：职位匹配、课程推荐

## 2. 目录结构（示例）
```
discover-myself/
├─ src/
│   ├─ assets/                 # 图片、音频、动画
│   │   ├─ images/
│   │   ├─ sounds/
│   │   └─ animations/
│   ├─ data/                   # 题库、模型、奖品、推荐等 JSON
│   │   ├─ questions.json
│   │   ├─ models.json
│   │   ├─ prizes.json
│   │   ├─ career.json
│   │   └─ recommendations.json
│   ├─ db/                     # 本地数据库封装
│   │   └─ database.js
│   ├─ encryption/             # AES + 密钥管理
│   │   └─ crypto.js
│   ├─ services/                # 核心业务逻辑
│   │   ├─ assessment.js
│   │   ├─ recommendation.js
│   │   ├─ achievement.js
│   │   └─ lottery.js
│   ├─ utils/                   # 通用工具
│   │   └─ random.js
│   └─ App.{js,tsx,rb}          # 入口文件 (React Native / Flutter / PWA)
├─ package.json                # 依赖、脚本
├─ android/                    # 原生 Android 项目（可选）
├─ ios/                        # 原生 iOS 项目（可选）
└─ README.md                   # 说明文档
```

## 3. 文件说明
- **assets/** – 所有 UI 资源，保持压缩，便于打包。
- **data/** – 所有业务数据。
  * `questions.json`：测试题目、选项、分数。<br>
  * `models.json`：评分公式、权重、阈值。<br>
  * `prizes.json`：抽奖奖品、库存、概率。<br>
  * `career.json`：职业定位表。<br>
  * `recommendations.json`：成长建议模板。
- **db/database.js**：使用 SQLite（原生）或 IndexedDB 包装，支持读写 JSON 对象。<br>
- **encryption/crypto.js**：AES‑256 CBC，使用 PBKDF2 + 设备指纹或 PIN 生成密钥，保证离线加密。<br>
- **services/**：核心业务。
  * `assessment.js`：问卷收集、分数计算、结果生成。<br>
  * `recommendation.js`：匹配模型、职业建议。<br>
  * `achievement.js`：积分、徽章、奖励记录。<br>
  * `lottery.js`：可重现 PRNG，按 `seed = timestamp + deviceId` 生成随机数，按中奖概率抽取奖品。<br>
- **utils/random.js**：可重现 PRNG (Mulberry32/alea)。
- **App.*x**：根据选择的技术栈完成入口页面、路由、图形化结果展示。

## 4. 程序流程演示
1. **首次启动**：弹出设置提示（设置 PIN / 指纹生**钥）。<br>
2. **进入测评**：按关卡模式进行，每完成一关弹出积分/徽章。<br>
3. **完成全部测评**：生成结果、成长树；弹出抽奖（本地随机）。<br>
4. **获取建议**：根据结果输出职业/课程建议。<br>
5. **导出**：PDF 报告（html‑to‑pdf），或直接分享截图。

## 5. 可选功能扩展
- **远程备份**：压缩加密后存至云盘或第三方存储。<br>
- **Web PWA**：离线缓存，支持 Service Worker 推送。<br>
- **多设备同步**：通过本地导入/导出文件实现手动同步。<br>
- **社群成就**：生成可分享的奖牌截图，包含可视化成长路线图。

---

此设计文件将作为项目的 **开始模板**，后续可按需更新、迭代。
