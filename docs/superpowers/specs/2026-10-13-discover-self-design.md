# 发现自我 - 离线自我评测游戏化平台 设计规格

日期: 2026-10-13
状态: 已批准

## 1. 项目概述

完全离线无后端的自我评测游戏化平台，Flutter 跨平台 iOS/Android。所有数据、题库、模型、抽奖保存在本地。通过游戏化反馈、积分、徽章、沉浸式动画激励用户完成测评流程。

项目名统一为 **发现自我**。

## 2. 目标与成功标准

* MVP 范围 C：人格+智商+情商+兴趣主流程 + 番外 MBTI/星座
* 成功标准 C：用户能完整跑通一次测评并生成 PDF，重复 3 次闭环，PIN 加密有效
* 数据安全：PIN + 本地加密，永不联网
* 导出：PDF 报告 + 截图分享

## 3. 技术栈

* 框架：Flutter 3.x
* 存储：sqflite + sqflite_sqlcipher
* 安全：flutter_secure_storage 存盐，PBKDF2 派生密钥
* 动画：Lottie / Rive
* 导出：pdf + printing，screenshot
* 资源：assets/data/*.json

## 4. 架构

目录结构:
lib/src/
  data/  JSON 资源
  db/    SQLite 封装
  encryption/ 密钥管理
  services/ assessment, achievement, lottery, recommendation
  models/
  ui/ onboarding, assessment, result, reward, growth
  utils/ prng, pdf_export

数据流：PIN 设置 → 解锁 DB → 加载 JSON → 关卡测评 → 计分 → 结果可视化 → 积分徽章 → 抽奖 → PDF 导出

## 5. 数据模型

SQLite 表:
users(id, pin_salt, created_at)
assessments(id, type, started_at, finished_at, score_json)
answers(assessment_id, question_id, option, value)
achievements(id, type, earned_at, points)
lottery_logs(id, seed, prize_id, drawn_at)
growth_goals(id, dimension, target, progress)

资源 JSON:
questions.json, models.json, prizes.json, career.json, recommendations.json

多档案支持：单 PIN 多 profile，profile 切换不重新验证，退出 App 需 PIN。

## 6. 加密与安全

* PIN 最小 4 位，PBKDF2-HMAC-SHA256 迭代 10000，salt 16B
* 数据库以派生密钥打开，密钥仅内存存在
* 后台 5 分钟自动锁定
* 无网络，所有操作本地

## 7. 游戏化流程

1. 首次启动 PIN 设置 + 档案创建
2. 主测评 4 关卡，每关完成给积分 + 徽章
3. 结果页星盘/成长树 + 优势/待提升
4. 番外 MBTI/星座
5. 成长建议职业匹配
6. 完成触发抽奖，PRNG Mulberry32，seed = timestamp_ms + deviceId_hash

抽奖低成本：本地权重表，无服务器验证。

## 8. 导出与资源

* PDF A4 报告：封面、画像总览、雷达图、建议
* 截图分享到相册
* 资源包约 10MB + Flutter 基线 40-60MB

## 9. 错误处理

* PIN 错误 5 次冷静 30s
* 存储不足提示
* 动画降级
* JSON 校验

## 10. 测试

* 单元：计分、PRNG 可重现、PBKDF2
* 集成：完整主流程
* 手工：3 次闭环、多档案、PIN 锁定

## 11. 约束与决策

* 完全离线，放弃社交排行榜
* 抽奖本地可信
* 低成本加密实现
* 项目名改为 发现自我

## 12. 下一步

进入实施计划编写。
