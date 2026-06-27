"""
Telegram Monitor — моніторинг загроз через Telegram Bot API.
Бот слухає повідомлення у приватному чаті або в каналах/групах, де він є адміністратором.
"""

import asyncio
import re
from datetime import datetime, timezone
from typing import Optional

from telethon import TelegramClient, events
from mock_mode import ThreatState, ALL_REGIONS, THREAT_TYPES

# === КОНФІГУРАЦІЯ ===
BOT_TOKEN = "8757178353:AAGFb6iwR0-Ftn7aLprQjyOT5DRKdnAALcg"
TELEGRAM_API_ID = 20294647
TELEGRAM_API_HASH = "454a9c055308a8d118608bb6b032bc30"
SESSION_NAME = "sirenua_bot_session"

# Ключові слова загроз
CRITICAL_KEYWORDS = [r"масований\s*(ракетний\s*)?удар", r"масований\s*обстріл", r"комбінований\s*удар"]
HIGH_KEYWORDS = [
    r"МіГ[-\s]?31", r"Кинджал", r"Ту[-\s]?95", r"Ту[-\s]?22", r"Ту[-\s]?160",
    r"стратегічн\w+\s*авіаці", r"крилат\w+\s*ракет", r"[ХX][-\s]?101",
    r"[ХX][-\s]?555", r"Калібр", r"Іскандер", r"балістичн\w+", r"пуски?\s*ракет"
]
MEDIUM_KEYWORDS = [r"[ШШ]ахед", r"Shahed", r"БПЛА", r"безпілотни", r"дрон", r"БпЛА"]
LOW_KEYWORDS = [r"зліт", r"підйом\s*авіаці", r"активність\s*авіаці"]
CLEAR_KEYWORDS = [r"відбій", r"загроз\w*\s*нема", r"загроз\w*\s*відсутн", r"збит[оіа]", r"знищен[оіа]", r"посадка"]

# Регіональні ключові слова
REGION_KEYWORDS = {
    "Київська область": [r"Київ", r"Києв", r"столиц"],
    "м. Київ": [r"м\.\s*Київ", r"столиц"],
    "Харківська область": [r"Харків", r"Харьків", r"харьк"],
    "Одеська область": [r"Одес", r"Одещин"],
    "Дніпропетровська область": [r"Дніпр", r"Дніпропетровськ"],
    "Львівська область": [r"Львів", r"Львівщин"],
    "Запорізька область": [r"Запорі"],
    "Миколаївська область": [r"Миколаї"],
    "Херсонська область": [r"Херсон"],
    "Полтавська область": [r"Полтав"],
    "Вінницька область": [r"Вінниц"],
    "Черкаська область": [r"Черкас"],
    "Чернігівська область": [r"Черніг"],
    "Сумська область": [r"Суми", r"Сумщин"],
    "Донецька область": [r"Донецьк", r"Донеччин"],
    "Луганська область": [r"Луганськ", r"Луганщин"],
    "Житомирська область": [r"Житомир"],
    "Рівненська область": [r"Рівн"],
    "Волинська область": [r"Волин"],
    "Тернопільська область": [r"Терноп"],
    "Хмельницька область": [r"Хмельниц"],
    "Кіровоградська область": [r"Кіровоград", r"Кропивниц"],
    "Івано-Франківська область": [r"Івано[-\s]?Франків", r"Франків"],
    "Закарпатська область": [r"Закарпат", r"Ужгород"],
    "Чернівецька область": [r"Чернівц"],
}

THREAT_AUTO_CLEAR_MINUTES = 45

class TelegramThreatMonitor:
    def __init__(self, threat_manager):
        self.threat_manager = threat_manager
        self.client: Optional[TelegramClient] = None
        self.is_running = False
        self._clear_tasks = {}

    async def start(self):
        print("🔌 Підключення бота до Telegram...")
        # Авторизація за допомогою токена бота
        self.client = TelegramClient(SESSION_NAME, TELEGRAM_API_ID, TELEGRAM_API_HASH)
        await self.client.start(bot_token=BOT_TOKEN)
        
        me = await self.client.get_me()
        print(f"✅ Бот авторизований успішно: @{me.username}")
        
        @self.client.on(events.NewMessage)
        async def handler(event):
            await self._process_message(event.message)
            
        self.is_running = True
        print("📥 Бот готовий приймати повідомлення (додай його в канал/групу як адміна або пиши йому в приват).")

    async def stop(self):
        self.is_running = False
        for task in self._clear_tasks.values():
            task.cancel()
        self._clear_tasks.clear()
        if self.client:
            await self.client.disconnect()
        print("🛑 Бот зупинений")

    async def _process_message(self, message):
        if not message.text:
            return

        text = message.text
        # Додамо авто-відповідь у приватних чатах для підтвердження отримання
        if message.is_private:
            await message.reply("Отримав повідомлення, аналізую загрози...")

        # Перевірка на зняття загрози
        is_clear = any(re.search(kw, text, re.IGNORECASE) for kw in CLEAR_KEYWORDS)
        
        if is_clear:
            regions = self._extract_regions(text)
            if regions:
                for region in regions:
                    self.threat_manager.clear_threat(region)
                    if region in self._clear_tasks:
                        self._clear_tasks[region].cancel()
                msg = f"✅ Загрозу знято для: {', '.join(regions)}"
            else:
                self.threat_manager.clear_all()
                msg = "✅ Всі загрози скасовано (відбій тривог)"
            
            if message.is_private:
                await message.reply(msg)
            print(msg)
            return

        level = self._detect_threat_level(text)
        if not level:
            if message.is_private:
                await message.reply("Загрози не виявлено в тексті.")
            return

        threat_type = self._detect_threat_type(text)
        regions = self._extract_regions(text)
        
        if not regions and level in ("critical", "high"):
            regions = list(ALL_REGIONS)
            
        if not regions:
            if message.is_private:
                await message.reply("Виявлено загрозу, але не вдалося визначити область.")
            return

        detail = f"{THREAT_TYPES.get(threat_type, 'Загроза')}: {text[:80]}"
        for region in regions:
            self.threat_manager.set_threat(region, level, threat_type, detail)
            self._schedule_auto_clear(region)

        msg = f"🔴 Рівень {level.upper()} встановлено для {len(regions)} областей."
        if message.is_private:
            await message.reply(msg)
        print(msg)

    def _detect_threat_level(self, text: str) -> Optional[str]:
        for kw in CRITICAL_KEYWORDS:
            if re.search(kw, text, re.IGNORECASE): return "critical"
        for kw in HIGH_KEYWORDS:
            if re.search(kw, text, re.IGNORECASE): return "high"
        for kw in MEDIUM_KEYWORDS:
            if re.search(kw, text, re.IGNORECASE): return "medium"
        for kw in LOW_KEYWORDS:
            if re.search(kw, text, re.IGNORECASE): return "low"
        return None

    def _detect_threat_type(self, text: str) -> Optional[str]:
        if re.search(r"МіГ[-\s]?31|Кинджал", text, re.IGNORECASE): return "mig31k"
        if re.search(r"Ту[-\s]?95|Ту[-\s]?160", text, re.IGNORECASE): return "tu95"
        if re.search(r"крилат\w+\s*ракет|[ХX][-\s]?101", text, re.IGNORECASE): return "cruise_missile"
        if re.search(r"[ШШ]ахед|Shahed", text, re.IGNORECASE): return "shahed"
        return None

    def _extract_regions(self, text: str) -> list[str]:
        found = set()
        for region, keywords in REGION_KEYWORDS.items():
            for kw in keywords:
                if re.search(kw, text, re.IGNORECASE):
                    found.add(region)
                    break
        return list(found)

    def _schedule_auto_clear(self, region: str):
        if region in self._clear_tasks:
            self._clear_tasks[region].cancel()
        
        async def clear_after_delay():
            await asyncio.sleep(THREAT_AUTO_CLEAR_MINUTES * 60)
            self.threat_manager.clear_threat(region)
            
        self._clear_tasks[region] = asyncio.create_task(clear_after_delay())
