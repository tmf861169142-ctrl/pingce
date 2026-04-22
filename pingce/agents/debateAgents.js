const OpenAI = require('openai');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// 模拟检索函数
const searchKnowledge = async (query) => {
  // 实际应用中可以集成真实的搜索引擎或知识库
  console.log(`检索: ${query}`);
  // 模拟检索结果
  return [
    `关于 "${query}" 的权威信息 1`,
    `关于 "${query}" 的权威信息 2`,
    `关于 "${query}" 的权威信息 3`
  ];
};

// 单个评审员智能体
const reviewerAgent = async (atom, reviewerId) => {
  try {
    // 步骤1: 评估置信度
    const confidenceResponse = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: '你是一个知识评审员，需要评估对给定论断的置信度。请基于你的知识，对以下论断的正确性给出0-100的置信度评分，并简要说明理由。'
        },
        {
          role: 'user',
          content: atom.content
        }
      ],
      temperature: 0.3
    });
    
    const confidenceText = confidenceResponse.choices[0].message.content;
    const confidence = parseInt(confidenceText.match(/\d+/)[0]);
    
    let evidence = [];
    let reasoning;
    
    // 步骤2: 根据置信度选择流程
    if (confidence < 70) {
      // 检索后发言
      evidence = await searchKnowledge(atom.content);
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4',
        messages: [
          {
            role: 'system',
            content: '你是一个知识评审员，基于检索到的证据，对给定论断的正确性进行判断，并提供详细理由。'
          },
          {
            role: 'user',
            content: `论断: ${atom.content}\n\n检索证据:\n${evidence.join('\n')}\n\n请判断该论断是 TRUE 还是 FALSE，并提供详细理由。`
          }
        ],
        temperature: 0.3
      });
      
      reasoning = response.choices[0].message.content;
    } else {
      // 直接发言
      const response = await openai.chat.completions.create({
        model: 'gpt-4',
        messages: [
          {
            role: 'system',
            content: '你是一个知识评审员，基于你的知识库，对给定论断的正确性进行判断，并提供详细理由。'
          },
          {
            role: 'user',
            content: `论断: ${atom.content}\n\n请判断该论断是 TRUE 还是 FALSE，并提供详细理由。`
          }
        ],
        temperature: 0.3
      });
      
      reasoning = response.choices[0].message.content;
    }
    
    // 提取判断结果
    const isTrue = reasoning.toLowerCase().includes('true');
    
    return {
      reviewerId,
      atomId: atom.id,
      judgment: isTrue ? 'TRUE' : 'FALSE',
      reasoning,
      evidence,
      confidence
    };
  } catch (error) {
    console.error(`评审员 ${reviewerId} 出错:`, error);
    throw error;
  }
};

// 多智能体辩论
const debateOnAtoms = async (atoms) => {
  const debateResults = [];
  const reviewerCount = 3; // 评审员数量
  
  for (const atom of atoms) {
    console.log(`正在辩论原子论断: ${atom.content}`);
    
    const reviewerPromises = [];
    for (let i = 1; i <= reviewerCount; i++) {
      reviewerPromises.push(reviewerAgent(atom, `reviewer_${i}`));
    }
    
    const atomDebateResults = await Promise.all(reviewerPromises);
    debateResults.push({
      atomId: atom.id,
      atomContent: atom.content,
      reviews: atomDebateResults
    });
  }
  
  return debateResults;
};

module.exports = {
  debateOnAtoms
};