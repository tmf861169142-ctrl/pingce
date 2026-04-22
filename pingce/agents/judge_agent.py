import os
from openai import OpenAI

client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

def integrate_judgments(debate_results, original_atoms):
    try:
        atom_results = []
        total_true = 0
        total_false = 0
        
        for debate in debate_results:
            # 统计评审员判断
            true_count = sum(1 for review in debate['reviews'] if review['judgment'] == 'TRUE')
            false_count = sum(1 for review in debate['reviews'] if review['judgment'] == 'FALSE')
            
            # 基于投票结果和理由综合判断
            response = client.chat.completions.create(
                model='gpt-4',
                messages=[
                    {
                        'role': 'system',
                        'content': '你是一个公正的法官，负责基于评审员的判断和理由，对原子论断的事实正确性做出最终判决。请综合考虑所有评审员的意见、理由的合理性以及证据的充分性，给出最终的 TRUE/FALSE 判断，并提供详细的判决理由。'
                    },
                    {
                        'role': 'user',
                        'content': f'原子论断: {debate["atomContent"]}\n\n评审员意见:\n' + '\n\n'.join([f'评审员 {review["reviewerId"]}: {review["judgment"]}\n理由: {review["reasoning"]}\n证据: {"，".join(review["evidence"]) if review["evidence"] else "无"}\n置信度: {review["confidence"]}' for review in debate['reviews']]) + '\n\n请给出最终判决（TRUE/FALSE）和详细理由。'
                    }
                ],
                temperature=0.3
            )
            
            judgment_text = response.choices[0].message.content
            final_judgment = 'TRUE' if 'true' in judgment_text.lower() else 'FALSE'
            
            if final_judgment == 'TRUE':
                total_true += 1
            else:
                total_false += 1
            
            atom_results.append({
                'atomId': debate['atomId'],
                'atomContent': debate['atomContent'],
                'finalJudgment': final_judgment,
                'judgmentReason': judgment_text,
                'reviews': debate['reviews']
            })
        
        # 计算整体准确率
        total_atoms = len(atom_results)
        accuracy = (total_true / total_atoms * 100) if total_atoms > 0 else 0
        
        # 生成整体评测报告
        report = {
            'totalAtoms': total_atoms,
            'trueCount': total_true,
            'falseCount': total_false,
            'accuracy': f'{accuracy:.2f}%',
            'atomResults': atom_results,
            'summary': f'本次评测共分析了 {total_atoms} 个原子论断，其中 {total_true} 个正确，{total_false} 个错误，整体准确率为 {accuracy:.2f}%。'
        }
        
        return report
    except Exception as e:
        print('判断整合失败:', e)
        raise