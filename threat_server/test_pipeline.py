import sys
import os
import asyncio
import re

# Add threat_server path to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from mock_mode import MockThreatManager, ALL_REGIONS
from telegram_monitor import TelegramThreatMonitor

class TestThreatManager(MockThreatManager):
    def __init__(self):
        super().__init__()
        self.sent_notifications = []

    def set_threat(self, region: str, level: str, threat_type=None, detail=None):
        res = super().set_threat(region, level, threat_type, detail)
        self.sent_notifications.append({
            "region": region,
            "level": level,
            "type": threat_type,
            "detail": detail
        })
        return res

    def clear_threat(self, region: str) -> bool:
        res = super().clear_threat(region)
        self.sent_notifications.append({
            "region": region,
            "level": "none",
            "type": None,
            "detail": None
        })
        return res

    def clear_all(self):
        super().clear_all()
        for region in ALL_REGIONS:
            self.sent_notifications.append({
                "region": region,
                "level": "none",
                "type": None,
                "detail": None
            })

async def run_tests():
    print("==================================================")
    print("🧪 Запуск тестування повного циклу парсингу та логіки")
    print("==================================================\n")

    threat_manager = TestThreatManager()
    monitor = TelegramThreatMonitor(threat_manager)
    monitor.is_running = True

    # Тест 1: Зліт МіГ-31К (загальнонаціональна загроза HIGH)
    print("📌 Тест 1: Зліт МіГ-31К...")
    threat_manager.sent_notifications.clear()
    msg = "Увага! Зліт МіГ-31К з аеродрому Саваслейка! Загроза застосування ракет Кинджал по всій території України!"
    await monitor._process_message(msg, "kpszsu")
    
    assert len(threat_manager.sent_notifications) > 0, "Має бути надіслано сповіщення!"
    first_notif = threat_manager.sent_notifications[0]
    print(f"✅ Рівень загрози: {first_notif['level'].upper()}")
    print(f"✅ Тип загрози: {first_notif['type']}")
    print(f"✅ Областей активовано: {len(threat_manager.sent_notifications)}")
    print(f"✅ Приклад деталізації: {first_notif['detail']}")
    assert first_notif["level"] == "high"
    assert first_notif["type"] == "mig31k"
    print("--------------------------------------------------")

    # Тест 2: Шахеди в конкретних областях (MEDIUM)
    print("📌 Тест 2: Рух Шахедів у напрямку конкретних областей...")
    threat_manager.sent_notifications.clear()
    msg = "Шахеди з півдня! Зафіксовано рух ударних БпЛА в Одеській та Миколаївській областях. Напрямок на Кропивницький."
    await monitor._process_message(msg, "monitorwarr")
    
    regions = [n["region"] for n in threat_manager.sent_notifications]
    levels = [n["level"] for n in threat_manager.sent_notifications]
    types = [n["type"] for n in threat_manager.sent_notifications]
    
    print(f"✅ Виявлені області: {regions}")
    print(f"✅ Рівні загроз: {set(levels)}")
    print(f"✅ Типи загроз: {set(types)}")
    print(f"✅ Деталізація для Одеської: {[n['detail'] for n in threat_manager.sent_notifications if 'Одес' in n['region']][0]}")
    
    assert "Одеська область" in regions
    assert "Миколаївська область" in regions
    assert "Кіровоградська область" in regions
    assert all(lvl == "medium" for lvl in levels)
    assert all(t == "shahed" for t in types)
    print("--------------------------------------------------")

    # Тест 3: Загроза балістики (HIGH)
    print("📌 Тест 3: Загроза балістики з Криму...")
    threat_manager.sent_notifications.clear()
    msg = "Загроза балістики з Криму для Херсонської та Запорізької областей!"
    await monitor._process_message(msg, "eRadarrua")
    
    regions = [n["region"] for n in threat_manager.sent_notifications]
    levels = [n["level"] for n in threat_manager.sent_notifications]
    types = [n["type"] for n in threat_manager.sent_notifications]
    
    print(f"✅ Виявлені області: {regions}")
    print(f"✅ Рівні загроз: {set(levels)}")
    print(f"✅ Типи загроз: {set(types)}")
    
    assert "Херсонська область" in regions
    assert "Запорізька область" in regions
    assert all(lvl == "high" for lvl in levels)
    assert all(t == "ballistic" for t in types)
    print("--------------------------------------------------")

    # Тест 4: Ракети в напрямку (HIGH)
    print("📌 Тест 4: Ракети в напрямку області...")
    threat_manager.sent_notifications.clear()
    msg = "Увага! Крилаті ракети в повітряному просторі Київщини, напрямок на Васильків!"
    await monitor._process_message(msg, "vanek_nikolaev")
    
    regions = [n["region"] for n in threat_manager.sent_notifications]
    levels = [n["level"] for n in threat_manager.sent_notifications]
    types = [n["type"] for n in threat_manager.sent_notifications]
    
    print(f"✅ Виявлені області: {regions}")
    print(f"✅ Рівні загроз: {set(levels)}")
    print(f"✅ Типи загроз: {set(types)}")
    
    assert "Київська область" in regions
    assert all(lvl in ("high", "critical") for lvl in levels)
    assert all(t == "cruise_missile" for t in types)
    print("--------------------------------------------------")

    # Тест 5: Частковий відбій (NONE)
    print("📌 Тест 5: Частковий відбій тривоги...")
    threat_manager.sent_notifications.clear()
    msg = "Відбій повітряної тривоги в Одеській та Миколаївській областях."
    await monitor._process_message(msg, "kpszsu")
    
    cleared = [n for n in threat_manager.sent_notifications if n["level"] == "none"]
    regions = [n["region"] for n in cleared]
    print(f"✅ Скасовано загрозу для областей: {regions}")
    
    assert "Одеська область" in regions
    assert "Миколаївська область" in regions
    print("--------------------------------------------------")

    # Тест 6: Повний відбій (NONE для всіх)
    print("📌 Тест 6: Повний відбій...")
    threat_manager.sent_notifications.clear()
    msg = "Відбій загрози для всіх областей. Чисто."
    await monitor._process_message(msg, "kpszsu")
    
    cleared = [n for n in threat_manager.sent_notifications if n["level"] == "none"]
    print(f"✅ Скасовано загрозу для всіх {len(cleared)} областей України.")
    assert len(cleared) >= 24
    print("--------------------------------------------------")

    print("\n🎉 ВСІ ТЕСТИ ПРОЙДЕНО УСПІШНО! Логіка та парсер працюють ідеально!")
    print("==================================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
