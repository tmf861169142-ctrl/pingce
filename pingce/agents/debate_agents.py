import os
from openai import OpenAI

client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# 模拟检索函数
def search_knowledge(query):
    # 实际应用中可以集成真实的搜索引擎或知识库
    print(f'检索: {query}')
    # 模拟检索结果
    return [
        f'关于 "{query}" 的权威信息 1',
        f'关于 "{query}" 的权威信息 2',
        f'关于 "{query}" 的权威信息 3'
    ]

# 单个评审员智能体
def reviewer_agent(atom, reviewer_id):
    try:
        # 步骤1: 评估置信度
        confidence_response = client.chat.completions.create(
            model='gpt-4',
            messages=[
                {
                    'role': 'system',
                    'content': '你是一个知识评审员，需要评估对给定论断的置信度。请基于你的知识，对以下论断的正确性给出0-100的置信度评分，并简要说明理由。'
                },
                {
                    'role': 'user',
                    'content': atom['content']
                }
            ],
            temperature=0.3
        )
        
        confidence_text = confidence_response.choices[0].message.content
        # 提取置信度数值
        import re
        confidence_match = re.search(r'\d+', confidence_text)
        confidence = int(confidence_match.group(0)) if confidence_match else 50
        
        evidence = []
        reasoning = ''
        
        # 步骤2: 根据置信度选择流程
        if confidence < 70:
            # 检索后发言
            evidence = search_knowledge(atom['content'])
            
            response = client.chat.completions.create(
                model='gpt-4',
                messages=[
                    {
                        'role': 'system',
                        'content': '你是一个知识评审员，基于检索到的证据，对给定论断的正确性进行判断，并提供详细理由。'
                    },
                    {
                        'role': 'user',
                        'content': f'论断: {atom["content"]}\n\n检索证据:\n' + '\n'.join(evidence) + '\n\n请判断该论断是 TRUE 还是 FALSE，并提供详细理由。'
                    }
                ],
                temperature=0.3
            )
            
            reasoning = response.choices[0].message.content
        else:
            # 直接发言
            response = client.chat.completions.create(
                model='gpt-4',
                messages=[
                    {
                        'role': 'system',
                        'content': '你是一个知识评审员，基于你的知识库，对给定论断的正确性进行判断，并提供详细理由。'
                    },
                    {
                        'role': 'user',
                        'content': f'论断: {atom["content"]}\n\n请判断该论断是 TRUE 还是 FALSE，并提供详细理由。'
                    }
                ],
                temperature=0.3
            )
            
            reasoning = response.choices[0].message.content
        
        # 提取判断结果
        is_true = 'true' in reasoning.lower()
        
        return {
            'reviewerId': reviewer_id,
            'atomId': atom['id'],
            'judgment': 'TRUE' if is_true else 'FALSE',
            'reasoning': reasoning,
            'evidence': evidence,
            'confidence': confidence
        }
    except Exception as e:
        print(f'评审员 {reviewer_id} 出错:', e)
        raise

# 多智能体辩论
def debate_on_atoms(atoms):
    debate_results = []
    reviewer_count = 3  # 评审员数量
    
    for atom in atoms:
        print(f'正在辩论原子论断: {atom["content"]}')
        
        reviews = []
        for i in range(1, reviewer_count + 1):
            review = reviewer_agent(atom, f'reviewer_{i}')
            reviews.append(review)
        
        debate_results.append({
            'atomId': atom['id'],
            'atomContent': atom['content'],
            'reviews': reviews
        })
    
    return debate_results