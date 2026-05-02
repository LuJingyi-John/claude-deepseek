# claude-deepseek

让 Claude Code 用 DeepSeek 模型。

## 前置

- macOS / Linux
- [DeepSeek API Key](https://platform.deepseek.com)（新号送 $10）

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/LuJingyi-John/claude-deepseek/main/install.sh | bash
```

## 使用

```bash
claude
```

## 卸载

```bash
sed -i.bak '/# BEGIN claude-deepseek/,/# END claude-deepseek/d' ~/.zshrc
npm uninstall -g @anthropic-ai/claude-code
```
