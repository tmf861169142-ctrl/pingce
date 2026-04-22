const OpenAI = require('openai');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const integrateJudgments = async (debateResults, originalAtoms) => {
  try {
    const atomResults = [];
    let totalTrue = 0;
    let totalFalse = 0;
    
    for (const debate of debateResults) {
      // 统计评审员判断
      const trueCount = debate.reviews.filter(review => review.judgment === 'TRUE').length;
      const falseCount = debate.reviews.filter(review => review.judgment === 'FALSE').length;
      
      // 基于投票结果和理由综合判断
      const response = await openai.chat.completions.create({
        model: 'gpt-4',
        messages: [
          {
            role: 'system',
            content: '你是一个公正的法官，负责基于评审员的判断和理由，对原子论断的事实正确性做出最终判决。请综合考虑所有评审员的意见、理由的合理性以及证据的充分性，给出最终的 TRUE/FALSE 判断，并提供详细的判决理由。'
          },
          {
            role: 'user',
            content: `原子论断: ${debate.atomContent}\n\n评审员意见:\n${debate.reviews.map(review => `评审员 ${review.reviewerId}: ${review.judgment}\n理由: ${review.reasoning}\n证据: ${review.evidence.join(', ')}\n置信度: ${review.confidence}`).join('\n\n')}\n\n请给出最终判决（TRUE/FALSE）和详细理由。`
          }
        ],
        temperature: 0.3
      });
      
      const judgmentText = response.choices[0].message.content;
      const finalJudgment = judgmentText.toLowerCase().includes('true') ? 'TRUE' : 'FALSE';
      
      if (finalJudgment === 'TRUE') {
        totalTrue++;
      } else {
        totalFalse++;
      }
      
      atomResults.push({
        atomId: debate.atomId,
        atomContent: debate.atomContent,
        finalJudgment,
        judgmentReason: judgmentText,
        reviews: debate.reviews
      });
    }
    
    // 计算整体准确率
    const totalAtoms = atomResults.length;
    const accuracy = totalTrue / totalAtoms * 100;
    
    // 生成整体评测报告
    const report = {
      totalAtoms,
      trueCount: totalTrue,
      falseCount: totalFalse,
      accuracy: accuracy.toFixed(2) + '%',
      atomResults,
      summary: `本次评测共分析了 ${totalAtoms} 个原子论断，其中 ${totalTrue} 个正确，${totalFalse} 个错误，整体准确率为 ${accuracy.toFixed(2)}%。`
    };
    
    return report;
  } catch (error) {
    console.error('判断整合失败:', error);
    throw error;
  }
};

module.exports = {
  integrateJudgments
};