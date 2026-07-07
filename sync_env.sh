#!/bin/bash

# Configuration
SERVICE_ID="srv-d95na6kvikkc73duoca0"
ENV_FILE=".env"

# Extract keys from .env
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Помилка: Файл $ENV_FILE не знайдено."
    exit 1
fi

# Source .env safely without executing arbitrary commands, removing surrounding quotes
export RENDER_API_KEY=$(grep -E '^RENDER_API_KEY=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
export GEMINI_API_KEY=$(grep -E '^GEMINI_API_KEY=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'")
export SERVICE_ID

if [ -z "$RENDER_API_KEY" ]; then
    echo "❌ Помилка: RENDER_API_KEY не знайдено у $ENV_FILE"
    exit 1
fi

if [ -z "$GEMINI_API_KEY" ]; then
    echo "❌ Помилка: GEMINI_API_KEY не знайдено у $ENV_FILE"
    exit 1
fi

echo "🔄 Синхронізація GEMINI_API_KEY з сервером Render ($SERVICE_ID)..."

# Використовуємо Python для безпечної роботи з JSON та REST API Render
python3 -c "
import urllib.request
import urllib.error
import json
import sys
import os

RENDER_API_KEY = os.environ.get('RENDER_API_KEY')
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
SERVICE_ID = os.environ.get('SERVICE_ID')

headers = {
    'Authorization': f'Bearer {RENDER_API_KEY}',
    'Accept': 'application/json',
    'Content-Type': 'application/json'
}

# 1. Отримуємо поточні змінні оточення
req = urllib.request.Request(f'https://api.render.com/v1/services/{SERVICE_ID}/env-vars', headers=headers)
try:
    with urllib.request.urlopen(req) as response:
        env_vars = json.loads(response.read().decode())
except urllib.error.URLError as e:
    print(f'❌ Не вдалося отримати змінні з Render: {e}')
    sys.exit(1)

# 2. Оновлюємо або додаємо GEMINI_API_KEY
updated = False
put_payload = []

for item in env_vars:
    key = item['envVar']['key']
    value = item['envVar']['value']
    if key == 'GEMINI_API_KEY':
        put_payload.append({'key': key, 'value': GEMINI_API_KEY})
        updated = True
    else:
        put_payload.append({'key': key, 'value': value})

if not updated:
    put_payload.append({'key': 'GEMINI_API_KEY', 'value': GEMINI_API_KEY})

# 3. Відправляємо оновлений список назад
req_put = urllib.request.Request(
    f'https://api.render.com/v1/services/{SERVICE_ID}/env-vars',
    data=json.dumps(put_payload).encode('utf-8'),
    headers=headers,
    method='PUT'
)

try:
    with urllib.request.urlopen(req_put) as response:
        if response.getcode() == 200:
            print('✅ Успішно оновлено GEMINI_API_KEY на сервері Render. Сервер перезавантажується.')
        else:
            print(f'❌ Помилка оновлення, HTTP код: {response.getcode()}')
except urllib.error.URLError as e:
    print(f'❌ Не вдалося оновити змінні на Render: {e}')
    if hasattr(e, 'read'):
        print(e.read().decode('utf-8'))
    sys.exit(1)
"
