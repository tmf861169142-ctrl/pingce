from flask import Flask, request, jsonify
import os
from dotenv import load_dotenv
from agents.scribe_agent import atomize_text
from agents.debate_agents import debate_on_atoms
from agents.judge_agent import integrate_judgments

# 加载环境变量
load_dotenv()

app = Flask(__name__)

@app.route('/evaluate', methods=['POST'])
def evaluate():
    try:
        data = request.get_json()
        question = data.get('question')
        answer = data.get('answer')
        
        if not answer:
            return jsonify({'error': '缺少待评测内容'}), 400
            
        # 1. 原子论断分解
        print('开始原子论断分解...')
        atoms = atomize_text(answer)
        print('原子论断分解完成:', atoms)
        
        # 2. 多智能体辩论
        print('开始多智能体辩论...')
        debate_results = debate_on_atoms(atoms)
        print('多智能体辩论完成')
        
        # 3. 判断整合
        print('开始判断整合...')
        final_result = integrate_judgments(debate_results, atoms)
        print('判断整合完成')
        
        return jsonify({
            'question': question,
            'originalAnswer': answer,
            'atoms': atoms,
            'debateResults': debate_results,
            'finalResult': final_result
        })
    except Exception as e:
        print('评测过程中出错:', e)
        return jsonify({'error': '评测过程中出错'}), 500

@app.route('/', methods=['GET'])
def index():
    return app.send_static_file('index.html')

if __name__ == '__main__':
    port = int(os.getenv('PORT', 3000))
    app.run(host='0.0.0.0', port=port, debug=True)