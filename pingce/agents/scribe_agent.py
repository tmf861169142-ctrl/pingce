import os
from openai import OpenAI

client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

def atomize_text(text):
    try:
        response = client.chat.completions.create(
            model='gpt-4',
            messages=[
                {
                    'role': 'system',
                    'content': '你是一个专业的文本分析助手，负责将长文本拆解为原子论断。原子论断是不可再拆分、具备独立可验证性的事实陈述单元。例如，"北京是中国首都" 是一个独立论断，而 "北京是中国首都，面积约 1.6 万平方千米" 会拆分为两个可分别验证的单元。请将输入文本拆解为多个原子论断，每个论断一行。'
                },
                {
                    'role': 'user',
                    'content': text
                }
            ],
            temperature=0.3
        )
        
        atoms = response.choices[0].message.content.strip().split('\n')
        atoms = [atom.strip() for atom in atoms if atom.strip()]
        
        # 转换为字典格式
        atom_list = []
        for i, atom in enumerate(atoms, 1):
            atom_list.append({
                'id': f'atom_{i}',
                'content': atom
            })
        
        return atom_list
    except Exception as e:
        print('原子论断分解失败:', e)
        raise