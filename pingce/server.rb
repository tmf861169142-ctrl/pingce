require 'webrick'
require 'json'
require 'net/http'
require 'uri'

# 从.env文件加载环境变量
if File.exist?('.env')
  File.read('.env').each_line do |line|
    next if line.strip.empty? || line.strip.start_with?('#')
    key, value = line.strip.split('=', 2)
    ENV[key] = value
  end
end

# 千问API配置
QIANWEN_API_KEY = ENV['DASHSCOPE_API_KEY'] || ENV['QIANWEN_API_KEY'] || raise('API密钥环境变量未设置')
QIANWEN_API_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'
# 调用千问API的函数
def call_openai(messages, model = 'qwen-plus')
  uri = URI(QIANWEN_API_URL)
  headers = {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{QIANWEN_API_KEY}"
  }
  
  body = {
    'model' => model,
    'messages' => messages
  }
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  request = Net::HTTP::Post.new(uri.path, headers)
  request.body = body.to_json
  
  begin
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      return result['choices'][0]['message']['content']
    else
      error_message = "API错误: #{response.code} #{response.body}"
      puts error_message
      raise error_message
    end
  rescue => e
    error_message = "API调用失败: #{e.message}"
    puts error_message
    raise error_message
  end
end

class EvaluationHandler < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    if request.path == '/'
      # 读取静态HTML文件
      html_content = File.read('static/index.html')
      response.status = 200
      response['Content-Type'] = 'text/html'
      response.body = html_content
    else
      response.status = 404
      response.body = 'Not Found'
    end
  end

  def do_POST(request, response)
    if request.path == '/evaluate'
      begin
        puts "接收到评测请求"
        # 解析请求体
        body_content = request.body
        # 处理编码问题
        body_content = body_content.force_encoding('UTF-8') if body_content.respond_to?(:force_encoding)
        puts "请求体: #{body_content}"
        data = JSON.parse(body_content)
        question = data['question']
        answer = data['answer']
        puts "问题: #{question}"
        puts "回答: #{answer}"

        # 设置响应头部
        response.status = 200
        response['Content-Type'] = 'application/json'
        response['Access-Control-Allow-Origin'] = '*'

        # 使用OpenAI API进行原子论断分解
        puts "开始原子论断分解..."
        atomize_prompt = [
          {
            "role": "system",
            "content": "你是一个专业的文本分析助手，负责将长文本拆解为原子论断。原子论断是不可再拆分、具备独立可验证性的事实陈述单元。请严格按照用户输入的原始内容进行拆解，绝对不要修改、纠正、补充或生成任何信息。即使用户输入的内容在事实上是错误的，也必须完全保持原样。你只能从用户输入的内容中提取原子论断，不能自己创造任何内容。请只保留客观的事实陈述，过滤掉主观观点。例如，如果用户输入'我认为北京是中国首都'，你应该提取'北京是中国首都'作为原子论断。请将输入文本拆解为多个原子论断，每个论断一行。"
          },
          {
            "role": "user",
            "content": answer
          }
        ]
        
        begin
          atomize_result = call_openai(atomize_prompt)
        rescue => e
          error_data = { "error": "原子论断分解失败: #{e.message}" }
          response.body = JSON.generate(error_data)
          return
        end
        
        # 解析原子论断
        atom_sentences = atomize_result.split("\n").reject(&:empty?)
        atoms = atom_sentences.map.with_index(1) do |sentence, index|
          { "id": "atom_#{index}", "content": sentence.strip }
        end
        
        puts "原子论断分解完成: #{atoms}"

        # 使用OpenAI API进行多智能体辩论
        debate_results = []
        atoms.each do |atom|
          puts "开始评审原子论断: #{atom[:content]}"
          reviews = []
          
          # 3个评审员
          3.times do |i|
            reviewer_id = "reviewer_#{i+1}"
            
            # 评审员评估
            reviewer_prompt = [
              {
                "role": "system",
                "content": "你是一个知识评审员，负责对给定的论断进行评估。首先判断该论断是否是事实性论断（可以用正确与否评判的客观事实）。如果不是事实性论断（例如观点、意见、建议等），请输出'NON_FACT'并说明理由。如果是事实性论断，请基于你的知识判断其是否正确，并提供简洁的理由（几句话即可，不要长篇大论）。如果你的判断置信度低于70%，请简要说明需要进一步检索信息。"
              },
              {
                "role": "user",
                "content": "论断: #{atom[:content]}\n\n请首先判断该论断是否是事实性论断。如果不是，请输出'NON_FACT'并说明理由。如果是，请判断该论断是 TRUE 还是 FALSE，并提供简洁的理由（几句话即可，不要长篇大论）。"
              }
            ]
            
            begin
              review_result = call_openai(reviewer_prompt)
            rescue => e
              error_data = { "error": "评审员 #{reviewer_id} 评估失败: #{e.message}" }
              response.body = JSON.generate(error_data)
              return
            end
            
            # 提取判断结果
            if review_result.downcase.include?('non_fact') || review_result.downcase.include?('non-fact')
              judgment = "NON_FACT"
              # 提取置信度（优先匹配置信度相关的数字）
              confidence_match = review_result.match(/置信度[:：]\s*(\d+)/i) || review_result.match(/confidence[:：]\s*(\d+)/i) || review_result.match(/\d+%/)
              if confidence_match
                # 提取数字部分
                confidence_num = confidence_match[0].gsub(/[^0-9]/, '')
                confidence = confidence_num.to_i
              else
                confidence = 80
              end
            else
              is_true = review_result.downcase.include?('true')
              judgment = is_true ? "TRUE" : "FALSE"
              # 提取置信度（优先匹配置信度相关的数字）
              confidence_match = review_result.match(/置信度[:：]\s*(\d+)/i) || review_result.match(/confidence[:：]\s*(\d+)/i) || review_result.match(/\d+%/)
              if confidence_match
                # 提取数字部分
                confidence_num = confidence_match[0].gsub(/[^0-9]/, '')
                confidence = confidence_num.to_i
              else
                confidence = 80
              end
            end
            
            # 确保置信度在0-100之间
            confidence = [0, [100, confidence].min].max
            
            reviews << {
              "reviewerId": reviewer_id,
              "atomId": atom[:id],
              "judgment": judgment,
              "reasoning": review_result,
              "evidence": [],
              "confidence": confidence
            }
          end
          
          debate_results << {
            "atomId": atom[:id],
            "atomContent": atom[:content],
            "reviews": reviews
          }
        end
        
        # 使用OpenAI API进行判断整合
        puts "开始判断整合..."
        atom_results = []
        total_true = 0
        total_false = 0
        
        debate_results.each do |debate|
          # 法官整合
          judge_prompt = [
            {
              "role": "system",
              "content": "你是一个公正的法官，负责基于评审员的判断和理由，对原子论断做出最终判决。首先判断该论断是否是事实性论断（可以用正确与否评判的客观事实）。如果不是事实性论断（例如观点、意见、建议等），请输出'NON_FACT'并说明理由。如果是事实性论断，请综合考虑所有评审员的意见、理由的合理性，给出最终的 TRUE/FALSE 判断，并提供简洁的判决理由（几句话即可，不要长篇大论）。"
            },
            {
              "role": "user",
              "content": "原子论断: #{debate[:atomContent]}\n\n评审员意见:\n#{debate[:reviews].map { |r| "评审员 #{r[:reviewerId]}: #{r[:judgment]}\n理由: #{r[:reasoning]}\n置信度: #{r[:confidence]}" }.join('\n\n')}\n\n请首先判断该论断是否是事实性论断。如果不是，请输出'NON_FACT'并说明理由。如果是，请给出最终判决（TRUE/FALSE）和简洁的理由（几句话即可，不要长篇大论）。"
            }
          ]
          
          begin
            judge_result = call_openai(judge_prompt)
          rescue => e
            error_data = { "error": "判断整合失败: #{e.message}" }
            response.body = JSON.generate(error_data)
            return
          end
          
          # 提取最终判断
          if judge_result.downcase.include?('non_fact') || judge_result.downcase.include?('non-fact')
            final_judgment = "NON_FACT"
            # 非事实性论断不统计到正确或错误计数中
          else
            final_judgment = judge_result.downcase.include?('true') ? "TRUE" : "FALSE"
            
            if final_judgment == "TRUE"
              total_true += 1
            else
              total_false += 1
            end
          end
          
          atom_results << {
            "atomId": debate[:atomId],
            "atomContent": debate[:atomContent],
            "finalJudgment": final_judgment,
            "judgmentReason": judge_result,
            "reviews": debate[:reviews]
          }
        end
        
        # 计算整体准确率
        total_atoms = atoms.length
        accuracy = total_atoms > 0 ? (total_true.to_f / total_atoms * 100).round(2) : 0
        
        # 生成最终结果
        final_result = {
          "totalAtoms": total_atoms,
          "trueCount": total_true,
          "falseCount": total_false,
          "accuracy": "#{accuracy}%",
          "atomResults": atom_results,
          "summary": "本次评测共分析了 #{total_atoms} 个原子论断，其中 #{total_true} 个正确，#{total_false} 个错误，整体准确率为 #{accuracy}%。"
        }

        # 构建响应
        response_data = {
          "question": question,
          "originalAnswer": answer,
          "atoms": atoms,
          "debateResults": debate_results,
          "finalResult": final_result
        }
        
        puts "响应数据: #{response_data}"

        # 返回结果
        response.body = JSON.generate(response_data)
        puts "响应发送成功"
      rescue => e
        error_message = e.message
        puts "错误: #{error_message}"
        puts "错误堆栈: #{e.backtrace.join('\n')}"
        response.status = 500
        response['Content-Type'] = 'application/json'
        response['Access-Control-Allow-Origin'] = '*'
        # 直接返回详细的错误信息
        response.body = JSON.generate({ "error": error_message })
      end
    else
      response.status = 404
      response.body = 'Not Found'
    end
  end
end

# 创建服务器
server = WEBrick::HTTPServer.new(
  Port: 3000,
  DocumentRoot: './static'
)

# 注册处理器
server.mount('/', EvaluationHandler)
server.mount('/evaluate', EvaluationHandler)

# 启动服务器
puts "服务器运行在 http://localhost:3000"
trap('INT') { server.shutdown }
server.start