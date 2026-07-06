import asyncio
import re
import aiohttp
from bs4 import BeautifulSoup
from mock_mode import ThreatState, ALL_REGIONS, THREAT_TYPES

# Target Telegram channels to monitor
TARGET_CHANNELS = [
    "kpszsu",            # Повітряні Сили ЗСУ
    "monitorwarr",       # Найшвидша аналітика радарів
    "vanek_nikolaev"     # Николаевский Ванек
]

# Threat Keywords
CRITICAL_KEYWORDS = [r"масований\s*(ракетний\s*)?удар", r"масований\s*обстріл", r"комбінований\s*удар"]
HIGH_KEYWORDS = [
    r"МіГ[-\s]?31", r"Кинджал", r"Ту[-\s]?95", r"Ту[-\s]?22", r"Ту[-\s]?160",
    r"стратегічн\w+\s*авіаці", r"крилат\w+\s*ракет", r"[ХX][-\s]?101",
    r"[ХX][-\s]?555", r"Калібр", r"Іскандер", r"балістичн\w+", r"пуски?\s*ракет"
]
MEDIUM_KEYWORDS = [r"[ШШ]ахед", r"Shahed", r"БПЛА", r"безпілотни", r"дрон", r"БпЛА", r"мопед"]
LOW_KEYWORDS = [r"зліт", r"підйом\s*авіаці", r"активність\s*авіаці", r"загроза\s*балістики"]
CLEAR_KEYWORDS = [r"відбій", r"загроз\w*\s*нема", r"загроз\w*\s*відсутн", r"збит[оіа]", r"знищен[оіа]", r"посадка", r"чисто", r"дорозвідка"]

class TelegramThreatMonitor:
    def __init__(self, threat_manager):
        self.threat_manager = threat_manager
        self.is_running = False
        self._clear_tasks = {}
        # Stores the last seen post ID for each channel to avoid duplicate processing
        self.last_seen_posts = {channel: None for channel in TARGET_CHANNELS}

    async def start(self):
        print("🌐 Запуск Web Scraper для Telegram каналів...")
        self.is_running = True
        asyncio.create_task(self._scrape_loop())
        print(f"📥 Автоматичний моніторинг (кожні 20 сек) активний для: {', '.join(TARGET_CHANNELS)}")

    async def stop(self):
        self.is_running = False
        print("🛑 Web Scraper зупинено.")

    async def _scrape_loop(self):
        async with aiohttp.ClientSession() as session:
            while self.is_running:
                for channel in TARGET_CHANNELS:
                    await self._scrape_channel(session, channel)
                await asyncio.sleep(20)

    async def _scrape_channel(self, session, channel):
        url = f"https://t.me/s/{channel}"
        try:
            async with session.get(url, timeout=10) as response:
                if response.status != 200:
                    return
                html = await response.text()
                soup = BeautifulSoup(html, 'html.parser')
                
                messages = soup.select('.tgme_widget_message')
                if not messages:
                    return
                
                # Check if it's the first run (baseline) for this channel
                is_first_run = self.last_seen_posts[channel] is None
                
                # If first run, find the latest post ID and set it as baseline to avoid spamming historical messages
                if is_first_run:
                    max_id = 0
                    for msg in messages:
                        post_id = msg.get('data-post')
                        if post_id:
                            try:
                                current_id = int(post_id.split('/')[-1])
                                if current_id > max_id:
                                    max_id = current_id
                                    self.last_seen_posts[channel] = post_id
                            except:
                                continue
                    print(f"📡 [{channel}] Первинний запуск. Встановлено базовий ID поста: {max_id}")
                    return

                # For subsequent runs, iterate through all messages on the page and process those newer than last_seen_post
                last_id = 0
                if self.last_seen_posts[channel] is not None:
                    last_id = int(self.last_seen_posts[channel].split('/')[-1])

                for msg in messages:
                    post_id = msg.get('data-post')
                    if not post_id:
                        continue
                        
                    try:
                        current_id = int(post_id.split('/')[-1])
                        if current_id <= last_id:
                            continue
                        
                        # Update the last seen ID
                        self.last_seen_posts[channel] = post_id
                    except:
                        continue

                    # Extract text
                    text_div = msg.select_one('.tgme_widget_message_text')
                    if text_div:
                        for br in text_div.find_all("br"):
                            br.replace_with("\n")
                        text = text_div.get_text()
                        
                        # Logging every single read message to console for transparency
                        print(f"📖 [{channel}] Отримано нове повідомлення (ID: {current_id}): \"{text.strip().replace('\n', ' ')[:80]}...\"")
                        await self._process_message(text, channel)
        except Exception as e:
            # Silent fallback for network request errors
            pass

    async def _process_message(self, text, channel):
        # Check if it's a clear/end alert message
        is_clear = any(re.search(kw, text, re.IGNORECASE) for kw in CLEAR_KEYWORDS)
        
        if is_clear:
            regions = self._extract_regions(text)
            if regions:
                for region in regions:
                    self.threat_manager.clear_threat(region)
                    if region in self._clear_tasks:
                        self._clear_tasks[region].cancel()
                print(f"🟢 [{channel}] Зняття загрози розпізнано для: {', '.join(regions)}")
            else:
                self.threat_manager.clear_all()
                print(f"🟢 [{channel}] Зняття загрози розпізнано для ВСІХ областей (відбій/чисто)")
            return

        level = self._detect_threat_level(text)
        if not level:
            print(f"💡 [{channel}] Повідомлення проігноровано (не містить ключових слів загроз)")
            return

        threat_type = self._detect_threat_type(text)
        regions = self._extract_regions(text)
        
        # If threat level is high/critical and no specific regions mentioned, assume entire Ukraine
        if not regions and level in ("critical", "high"):
            regions = list(ALL_REGIONS)
            print(f"🚨 [{channel}] Виявлено загальну небезпеку {level.upper()} для всієї України")
            
        if not regions:
            print(f"💡 [{channel}] Рівень {level.upper()} розпізнано, але не знайдено відповідних областей")
            return

        detail = f"{THREAT_TYPES.get(threat_type, 'Загроза')}: {text.strip().replace('\n', ' ')[:80]}..."
        for region in regions:
            self.threat_manager.set_threat(region, level, threat_type, detail)
            self._schedule_auto_clear(region)

        print(f"🔴 [{channel}] Рівень {level.upper()} встановлено для {len(regions)} областей: {', '.join(regions)}")

    def _detect_threat_level(self, text: str):
        if any(re.search(kw, text, re.IGNORECASE) for kw in CRITICAL_KEYWORDS):
            return "critical"
        if any(re.search(kw, text, re.IGNORECASE) for kw in HIGH_KEYWORDS):
            return "high"
        if any(re.search(kw, text, re.IGNORECASE) for kw in MEDIUM_KEYWORDS):
            return "medium"
        if any(re.search(kw, text, re.IGNORECASE) for kw in LOW_KEYWORDS):
            return "low"
        return None

    def _detect_threat_type(self, text: str):
        text_lower = text.lower()
        if any(kw in text_lower for kw in ["шахед", "shahed", "бпла", "дрон", "мопед"]):
            return "shahed"
        if any(kw in text_lower for kw in ["балісти", "іскандер", "кинджал"]):
            return "ballistic"
        if any(kw in text_lower for kw in ["ракета", "крилата", "калібр", "х-101"]):
            return "cruise_missile"
        if any(kw in text_lower for kw in ["міг", "ту-", "авіація"]):
            return "mig31k" if "міг" in text_lower else "tu95"
        if any(kw in text_lower for kw in ["артилерія", "рсзв", "обстріл"]):
            return "artillery"
        return "unknown"

    def _extract_regions(self, text: str):
        found = set()
        for region, info in ALL_REGIONS.items():
            for kw in info["keywords"]:
                if re.search(kw, text, re.IGNORECASE):
                    found.add(region)
        return list(found)

    def _schedule_auto_clear(self, region: str):
        if region in self._clear_tasks:
            self._clear_tasks[region].cancel()
        
        async def auto_clear():
            await asyncio.sleep(3600)  # 1 hour auto-cleanup timeout
            self.threat_manager.clear_threat(region)
            print(f"⏳ Автоматичне зняття загрози для {region} (таймаут 1 год)")
            
        self._clear_tasks[region] = asyncio.create_task(auto_clear())
