const express = require('express');
const dotenv = require('dotenv');
const evaluationController = require('./controllers/evaluationController');

// 加载环境变量
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// 中间件
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 路由
app.post('/evaluate', evaluationController.evaluate);
app.get('/', (req, res) => {
  res.send('多智能体评测系统');
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`服务器运行在 http://localhost:${PORT}`);
});

module.exports = app;