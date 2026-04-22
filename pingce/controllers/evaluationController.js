const { atomizeText } = require('../agents/scribeAgent');
const { debateOnAtoms } = require('../agents/debateAgents');
const { integrateJudgments } = require('../agents/judgeAgent');

const evaluate = async (req, res) => {
  try {
    const { question, answer } = req.body;
    
    if (!answer) {
      return res.status(400).json({ error: '缺少待评测内容' });
    }
    
    // 1. 原子论断分解
    console.log('开始原子论断分解...');
    const atoms = await atomizeText(answer);
    console.log('原子论断分解完成:', atoms);
    
    // 2. 多智能体辩论
    console.log('开始多智能体辩论...');
    const debateResults = await debateOnAtoms(atoms);
    console.log('多智能体辩论完成');
    
    // 3. 判断整合
    console.log('开始判断整合...');
    const finalResult = await integrateJudgments(debateResults, atoms);
    console.log('判断整合完成');
    
    res.json({
      question,
      originalAnswer: answer,
      atoms,
      debateResults,
      finalResult
    });
  } catch (error) {
    console.error('评测过程中出错:', error);
    res.status(500).json({ error: '评测过程中出错' });
  }
};

module.exports = {
  evaluate
};