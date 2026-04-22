# 多智能体评测系统

## 项目简介

本项目是一个针对大模型生成长文本回答的事实准确性设计的自动化评测方案，核心是通过「原子化拆解 - 多智能体辩论 - 判决整合」三步，解决传统评测中 "模糊判断、难以定位错误、可解释性差" 的问题，实现细粒度、可验证的长文本事实核查。

## 系统架构

### 1. 原子论断分解
- **功能**：将长文本拆解为若干原子论断（不可再拆分、具备独立可验证性的事实陈述单元）
- **实现**：使用 `scribe_agent.py` 中的 `atomize_text` 函数

### 2. 多智能体辩论
- **功能**：针对每个原子论断，由多个评审员智能体进行辩论
- **流程**：
  - 直接发言：基于自身知识库直接给出判断
  - 检索后发言：先触发外部知识检索，再基于检索结果发言
  - 自由检索后发言：根据置信度决定是否检索
- **实现**：使用 `debate_agents.py` 中的 `debate_on_atoms` 函数

### 3. 判断整合
- **功能**：汇总所有评审员的判断，输出最终结论
- **实现**：使用 `judge_agent.py` 中的 `integrate_judgments` 函数

## 技术栈

- Python 3.7+
- Flask 2.0.1
- OpenAI API

## 快速开始

### 1. 安装依赖

```bash
pip3 install -r requirements.txt
```

### 2. 配置环境变量

在 `.env` 文件中设置 OpenAI API 密钥：

```
OPENAI_API_KEY=your_openai_api_key_here
PORT=3000
```

### 3. 启动服务

```bash
python3 app.py
```

### 4. 使用 API

发送 POST 请求到 `/evaluate` 端点，请求体格式如下：

```json
{
  "question": "问题内容",
  "answer": "待评估的回答内容"
}
```

### 5. 响应格式

```json
{
  "question": "问题内容",
  "originalAnswer": "原始回答内容",
  "atoms": [
    {
      "id": "atom_1",
      "content": "原子论断1"
    },
    {
      "id": "atom_2",
      "content": "原子论断2"
    }
  ],
  "debateResults": [
    {
      "atomId": "atom_1",
      "atomContent": "原子论断1",
      "reviews": [
        {
          "reviewerId": "reviewer_1",
          "atomId": "atom_1",
          "judgment": "TRUE",
          "reasoning": "理由1",
          "evidence": ["证据1", "证据2"],
          "confidence": 90
        }
      ]
    }
  ],
  "finalResult": {
    "totalAtoms": 2,
    "trueCount": 1,
    "falseCount": 1,
    "accuracy": "50.00%",
    "atomResults": [
      {
        "atomId": "atom_1",
        "atomContent": "原子论断1",
        "finalJudgment": "TRUE",
        "judgmentReason": "判决理由1",
        "reviews": [...]}
    ],
    "summary": "本次评测共分析了 2 个原子论断，其中 1 个正确，1 个错误，整体准确率为 50.00%。"
  }
}
```

## 项目结构

```
pingce/
├── app.py              # 主应用文件
├── requirements.txt    # 依赖文件
├── .env                # 环境变量配置
├── agents/
│   ├── scribe_agent.py    # 书记员智能体
│   ├── debate_agents.py   # 辩论智能体
│   └── judge_agent.py     # 法官智能体
└── README.md           # 项目说明
```

## 注意事项

1. 本系统依赖 OpenAI API，需要设置有效的 API 密钥
2. 评测过程可能会产生一定的 API 调用费用
3. 对于长文本，评测时间可能会较长
4. 实际应用中，可以根据需要调整评审员数量和置信度阈值

## 未来优化方向

1. 集成真实的搜索引擎或知识库，提高检索质量
2. 增加更多评审员智能体，提高判断的多样性
3. 优化辩论机制，支持多轮辩论
4. 增加可视化界面，提高用户体验
5. 支持批量评测和结果分析