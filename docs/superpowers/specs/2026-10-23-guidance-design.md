# 发现自我 · 专业、职业与领导力建议 设计规格

日期: 2026-10-23
状态: 待实现

## 1. 背景与目标

现有测评覆盖大五人格、IQ、EQ 和霍兰德 RIASEC，共 19 个维度，结果页只给出总体评价、维度分数和简单的职业标签。用户希望进一步得到：

- 大学适合读什么专业；
- 以后适合从事什么职业；
- 更适合当领导，还是走执行/专业骨干路线。

本次新增一个离线、可解释的「发展建议」模块。它不依赖后端或大模型，全部由本地规则和内容库计算，适用于选专业、转专业、职业转型等场景。

成功标准：

- 新增 6 道工作风格题，测评流程完整跑通。
- 结果页可进入「发展建议」独立页，看到专业方向、职业方向、领导力定位和下一步行动。
- 每条建议都有匹配度、推荐理由；不满足最低要求时给出「需谨慎」提示。
- 旧测评（没有工作风格题）仍可使用，领导力部分标注「参考值」。
- `flutter test` 全绿，`flutter analyze` 无新增问题。

## 2. 非目标

- 不接入后端、云端 AI 或本地大模型。
- 不新增第三方依赖。
- 不覆盖海外院校、职业院校或具体录取分数线。
- 不生成或导出新的 PDF 报告。
- 不做长期成长档案、课程报名或求职服务。

## 3. 新增测评内容

### 3.1 题目

在 `assets/data/questions.json` 末尾新增 6 道 Likert 题，`type` 为 `workstyle`，选项统一为：

`["非常不同意", "不同意", "一般", "同意", "非常同意"]`

| id | dimension | reverse | 题目 |
|---|---|---|---|
| w1 | leadership_drive | false | 我愿意为团队的结果做最终决策，并承担相应责任。 |
| w2 | leadership_drive | false | 遇到分歧时，我愿意站出来协调并推动大家达成一致。 |
| w3 | execution_focus | false | 比起管理别人，我更愿意把一项明确的任务做到极致。 |
| w4 | execution_focus | false | 我享受把计划一步步落地、按时交付的过程。 |
| w5 | adaptability | false | 面对不确定的情况，我愿意快速尝试、边做边调整。 |
| w6 | adaptability | true | 我更喜欢稳定、可预期的工作节奏。 |

### 3.2 维度

在 `assets/data/models.json` 新增 3 个维度，`type` 为 `workstyle`，`kind` 为 `likert`，`max` 为 5，`threshold` 为 3.5：

| key | label | desc |
|---|---|---|
| leadership_drive | 领导意愿 | 愿意承担决策责任、协调分歧并推动团队。 |
| execution_focus | 执行偏好 | 偏好把明确任务落地、按计划交付。 |
| adaptability | 变化适应 | 面对不确定与变化时的尝试和调整意愿。 |

### 3.3 流程与展示

- `AssessmentScreen` 的阶段标题新增：`workstyle` → `第 5 关 · 工作风格`。
- `ResultScreen` 的类型标题新增 `workstyle` → `工作风格`，排序放在最后。
- 评分沿用现有 `AssessmentService`，不新增评分逻辑。
- 6 道题追加在兴趣题之后；从兴趣关进入工作风格关时，现有庆祝动画正常触发。
- 「总体评价」继续使用全部维度（含工作风格），不改变现有摘要逻辑；PDF 导出也会包含这三个新维度。

## 4. 本地内容库

### 4.1 专业大类 `assets/data/majors.json`

```json
{
  "version": 1,
  "clusters": [
    {
      "name": "计算机与人工智能",
      "summary": "以编程、算法、系统与数据为核心，适合喜欢抽象思考和持续学习的人。",
      "majors": ["计算机科学与技术", "软件工程", "人工智能", "数据科学与大数据技术", "网络空间安全"],
      "weights": {
        "investigative": 0.35,
        "logic": 0.25,
        "openness": 0.15,
        "conscientiousness": 0.15,
        "numerical": 0.10
      },
      "minimums": {"logic": 0.5}
    }
  ]
}
```

约束：

- 共 14 个专业大类：
  1. 计算机与人工智能
  2. 电子信息与自动化
  3. 机械与自动化
  4. 土木、建筑与城市规划
  5. 数学与基础理学
  6. 医学与健康
  7. 经济与金融
  8. 管理、市场与人力
  9. 法学与公共管理
  10. 教育与心理
  11. 传媒、设计与艺术
  12. 语言、文学与人文
  13. 环境、农业与食品
  14. 体育与康复
- 每个大类至少 3 个具体专业，`weights` 之和为 1.0（允许 ±0.001 误差）。
- `weights` 的 key 必须存在于 `models.json`。
- `minimums` 可省略；key 必须存在于该大类的 `weights` 中，值为 0-1 的归一化阈值。

### 4.2 职业库 `assets/data/careers_advice.json`

```json
{
  "version": 1,
  "items": [
    {
      "name": "软件工程师",
      "cluster": "计算机与人工智能",
      "weights": {
        "investigative": 0.35,
        "logic": 0.30,
        "conscientiousness": 0.20,
        "openness": 0.15
      },
      "entry": "从计算机相关专业、编程实习或初级开发岗位进入，作品集和项目经验比单一学历更重要。"
    }
  ]
}
```

约束：

- 至少 30 个职业，名称不重复。
- `cluster` 必须是 `majors.json` 中存在的大类名称。
- `weights` 之和为 1.0（允许 ±0.001 误差），key 必须存在于 `models.json`。
- `entry` 为一句中文入门路径说明。

## 5. 匹配算法

新增纯计算模块 `lib/src/services/guidance.dart`，输入分数、维度元数据、专业大类和职业库，输出 `GuidanceReport`。

### 5.1 归一化

所有维度通过 `DimensionInfo.normalized(score)` 转为 0-1：

- Likert：`score / max`；
- choice：`score` 本身（0-1）。

### 5.2 匹配度

对每个专业大类或职业：

1. 取出 `weights` 中在当前 `scores` 里存在的维度，记为可用维度。
2. 若没有可用维度，跳过该项。
3. `weightSum = 可用维度权重之和`。
4. `base = Σ(weight × normalized) / weightSum`。
5. 检查 `minimums`：若可用维度中存在 `normalized < min`，则 `caution = true`，`fit = base × 0.85`；否则 `fit = base`。
6. `fit` 限制在 0-1；展示时四舍五入为整数百分比。

排序按 `fit` 降序；并列时保持内容库原顺序。

### 5.3 推荐理由

- 对可用维度计算 `weight × normalized`，取贡献最大的前 2 个。
- 理由文案：`你的{label}（{百分比}%）与该方向匹配`，多个用「、」连接。
- 「需谨慎」文案：`该方向通常需要较强的{label}（建议 ≥{阈值百分比}%），你当前为 {实际百分比}%。`

### 5.4 输出数量

- 专业：前 5 个。
- 职业：前 8 个。
- 若内容不足，按实际数量返回。

## 6. 领导力定位

### 6.1 三项指数

所有分量先归一化；缺失分量自动在可用分量中重新归一化。

- **领导潜力** = 领导意愿 30% + 企业型 20% + 社交技能 20% + 情绪稳定 15% + 情绪调节 15%。
- **执行稳定性** = 执行偏好 30% + 尽责性 25% + 情绪调节 20% + 常规型 15% + 情绪稳定 10%。
- **专业深度** = 研究型 30% + 艺术型 20% + 开放性 20% + 内在动机 15% + 执行偏好 15%。

### 6.2 分类规则

按顺序判断，命中即停止：

1. 领导潜力 ≥ 65% 且执行稳定性 ≥ 65% → **混合型**
2. 领导潜力 ≥ 60% → **领导型**
3. 专业深度 ≥ 65% 且领导潜力 < 60% → **专业骨干型**
4. 执行稳定性 ≥ 60% → **执行型**
5. 其余 → **探索待发展**

### 6.3 解释与发展建议

- 解释引用领导/执行/专业三项指数中贡献最大的 3 个维度，说明「为什么是这类」。
- 每种类型给出 3 条建议：
  - **领导型**：从小团队负责人开始；练习授权与反馈；学会倾听执行层意见。
  - **执行型**：发挥可靠交付优势；主动争取小范围决策；补足跨部门沟通。
  - **专业骨干型**：持续深耕专业；练习把专业表达成他人能懂的语言；尝试技术带头人/专家路线。
  - **混合型**：选择管理或项目制路线；明确角色边界；培养战略视角。
  - **探索待发展**：多尝试不同角色；先建立一项可交付技能；3-6 个月复盘一次。
- 页面展示「领导潜力」「执行稳定性」两条分数条；专业深度用于分类和解释，不单独展示进度条。

## 7. 页面与交互

### 7.1 结果页入口

- 在「总体评价」卡片下方新增一张卡片：
  - 标题：`发展建议`
  - 副标题：`专业方向 · 职业方向 · 领导力定位`
  - 按钮：`查看建议`，key 为 `guidance_entry`
- 本次结果和回看模式都显示。

### 7.2 发展建议页

新建 `lib/src/ui/result/guidance_screen.dart`，`Scaffold` + `SingleChildScrollView`，key 为 `guidance_screen`。

顶部：

- 标题 `发展建议`。
- 说明：`无论你在选专业、转专业还是考虑职业转型，都可以把这部分作为参考。`
- 若 `hasWorkstyle == false`，显示提示：`本次测评未包含工作风格题，领导力判断为参考值。`，key 为 `guidance_reference_note`。

板块 1：推荐专业方向，key `guidance_majors`

- 每项卡片 key `major_card_$i`：
  - 大类名称 + 匹配度百分比；
  - 大类简介；
  - 具体专业 `Chip`；
  - 推荐理由；
  - 若需谨慎，显示橙色提示与原因。

板块 2：适合的职业方向，key `guidance_careers`

- 每项 key `career_item_$i`：
  - 职业名称 + 匹配度百分比；
  - 所属大类；
  - 推荐理由；
  - 入门路径说明。

板块 3：领导力定位，key `guidance_leadership`

- 类型徽章，key `leadership_type`。
- 两条 `LinearProgressIndicator`：key `leadership_bar`、`execution_bar`，并显示百分比。
- 解释文字。
- 3 条发展建议。

板块 4：下一步行动，key `guidance_next_steps`

- 自动生成 4 条：
  1. 对比专业：`先了解 {专业大类} 下 {专业1}、{专业2} 的课程设置与就业方向。`
  2. 职业访谈：`找 1-2 位 {职业} 从业者做信息访谈，确认日常工作内容。`
  3. 领导力动作：取该类型建议中的第一条。
  4. 小范围尝试：`用 3 个月做一次小范围尝试（课程/社团/实习），再回来复测。`

底部：

- 免责声明：`本建议基于你的自评结果，仅供探索参考，不替代专业咨询。`

### 7.3 导航与数据加载

- `ResultScreen` 增加可选回调 `onGuidance`；为 `null` 时不显示入口卡片。
- `RootFlow` 实现 `_openGuidance`：
  - 通过 `AppCoordinator.loadGuidanceContent()` 按需加载 `majors.json` 和 `careers_advice.json`；
  - 调用 `buildGuidance(...)` 生成报告；
  - push `GuidanceScreen`。
- 加载失败或 JSON 无效：显示 `建议数据加载失败`，停留在结果页，不影响其他功能。
- 不新增数据库表；建议由已存分数实时计算。
- `GuidanceScreen` 构造参数：`GuidanceScreen({required GuidanceReport report, required String profileName})`。
- 两个 JSON 文件放在 `assets/data/` 下，沿用现有目录声明，不需要修改 `pubspec.yaml` 的 assets 列表。

## 8. 数据模型

新增 `lib/src/models/guidance.dart`：

```dart
class MajorCluster {
  final String name;
  final String summary;
  final List<String> majors;
  final Map<String, double> weights;
  final Map<String, double> minimums;
}

class CareerAdviceItem {
  final String name;
  final String cluster;
  final Map<String, double> weights;
  final String entry;
}

class GuidanceContent {
  final List<MajorCluster> clusters;
  final List<CareerAdviceItem> careers;
}

class MajorFit {
  final String cluster;
  final String summary;
  final List<String> majors;
  final double fit;
  final List<String> reasons;
  final String? caution;
}

class CareerFit {
  final String name;
  final String cluster;
  final double fit;
  final List<String> reasons;
  final String entry;
}

class LeadershipProfile {
  final LeadershipType type;
  final double leadership;
  final double execution;
  final double professionalDepth;
  final List<String> reasons;
  final List<String> tips;
}

enum LeadershipType { leader, executor, specialist, hybrid, explorer }

class GuidanceReport {
  final List<MajorFit> majors;
  final List<CareerFit> careers;
  final LeadershipProfile leadership;
  final List<String> nextSteps;
  final bool hasWorkstyle;
}
```

`buildGuidance` 签名：

```dart
GuidanceReport buildGuidance({
  required Map<String, double> scores,
  required List<DimensionInfo> dimensions,
  required GuidanceContent content,
});
```

## 9. 错误处理与兼容性

- `hasWorkstyle` 只有在三个工作风格维度（`leadership_drive`、`execution_focus`、`adaptability`）都存在时才为 `true`；缺任意一个即为 `false`，页面显示参考提示。
- 旧测评缺少工作风格维度：三项指数在可用分量中重新归一化；页面显示参考提示。
- 权重包含未知维度：加载时忽略，不参与计算；若某项无可用维度则跳过。
- 多个 `minimums` 未达标时，`caution` 一次列出全部未达标的维度；匹配度只乘一次 0.85，不重复惩罚。
- 专业或职业列表为空时，对应板块显示 `暂无可用建议`；两个都为空时，页面顶部显示一次 `暂无可用建议`，其余板块仍展示领导力定位。
- 匹配度限制在 0-1；展示百分比四舍五入并限制在 0-100。
- 并列排序保持内容库原顺序，结果可复现。
- 多档案：只使用当前档案分数。
- 不联网、不新增存储位置。

## 10. 测试

### 10.1 单元测试

- 五类领导力各用一组代表性分数，验证分类与边界（65%、60%）。
- 专业/职业匹配度：验证归一化加权、最低要求 ×0.85、排序、前 5/前 8 数量。
- 缺失工作风格维度：`hasWorkstyle == false`，领导力仍可计算且标注参考。
- 缺失部分权重维度：按可用维度重新归一化。
- 推荐理由取前两个贡献维度。
- 并列时顺序稳定。

### 10.2 内容库校验

- 所有 `weights` / `minimums` 的维度 key 存在于 `models.json`。
- 14 个专业大类；每类权重和约为 1；每类至少 3 个专业。
- 职业不少于 30 个，名称不重复。
- 每个职业的 `cluster` 存在于专业大类中。
- 每个职业权重和约为 1。

### 10.3 Widget 测试

- 结果页显示 `guidance_entry`，点击后进入 `guidance_screen`。
- 三个板块、领导力类型、两条分数条、下一步行动正常渲染。
- 旧测评显示 `guidance_reference_note`。
- 内容加载失败显示 `建议数据加载失败`，仍停留在结果页。
- 内容为空时显示 `暂无可用建议`。

### 10.4 回归

- 新增 6 题后，完整测评、关卡庆祝、结果分组、回看、PDF 导出全部通过。
- `flutter test` 全绿，`flutter analyze` 无新增问题。
- 真机手工检查：完成测评 → 查看发展建议 → 回看旧结果 → 检查参考提示。

## 11. 关键决策

- 采用加权匹配 + 本地内容库，保持离线、可解释、可测试。
- 新增 6 道工作风格题，不改变现有 19 个维度的含义。
- 专业建议取前 5、职业取前 8，避免信息过载。
- 领导力用五类定位 + 两条分数条，既给结论也给依据。
- 旧测评降级为参考值，不阻止回看。
- 内容库与算法分离，后续扩展只改 JSON。
