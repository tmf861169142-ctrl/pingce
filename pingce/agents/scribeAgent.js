const OpenAI = require('openai');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const atomizeText = async (text) => {
  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: '你是一个专业的文本分析助手，负责将长文本拆解为原子论断。原子论断是不可再拆分、具备独立可验证性的事实陈述单元。例如，"北京是中国首都" 是一个独立论断，而 "北京是中国首都，面积约 1.6 万平方千米" 会拆分为两个可分别验证的单元。请将输入文本拆解为多个原子论断，每个论断一行。'
        },
        {
          role: 'user',
          content: text
        }
      ],
      temperature: 0.3
    });
    
    const atoms = response.choices[0].message.content
      .split('\n')
      .filter(line => line.trim() !== '')
      .map((atom, index) => ({
        id: `atom_${index + 1}`,
        content: atom.trim()
      }));
    
    return atoms;
  } catch (error) {
    console.error('原子论断分解失败:', error);
    throw error;
  }
};

module.exports = {
  atomizeText
};