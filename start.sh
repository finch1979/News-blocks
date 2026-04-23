#!/usr/bin/env bash
cd "$(dirname "$0")"
[ ! -d ".venv" ] && python -m venv .venv
.venv/Scripts/pip install -r requirements.txt -q
echo "========================================="
echo "  方塊磚新聞 啟動中 → http://127.0.0.1:7788"
echo "========================================="
.venv/Scripts/python app.py
