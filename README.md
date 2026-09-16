# DataScout 📡

> **Prémium iOS Adatforgalom-kezelő & Valós Idejű Hálózati Telemetria Rendszer**  
> Swift 6 • SwiftUI • ActivityKit Dynamic Island • WidgetKit • Darwin Kernel 64-bit

[![iOS Version](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Version](https://img.shields.io/badge/version-v1.0.0-emerald.svg)](VERSIONING.md)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

A **DataScout** egy modern, natív iOS adatforgalom-követő alkalmazás és kiterjedt Widget ökoszisztéma, amelyet kifejezetten az **iPhone 14 Pro Max / 15 / 16 / 17 Pro** (430 pt, Dynamic Island) képernyőjére és a 2026-os **Liquid Glass** formanyelvre terveztünk.

---

## 🌟 Fő Funkciók

### 1. ⚡ 64-bites Hardveres Darwin Kernel Motor (`sysctl`)
- **Túlcsordulás-védelem:** A 32-bites `getifaddrs` 4,29 GB-os plafonja helyett a Darwin kernel 64-bites `NET_RT_IFLIST2` interfészét használja, amely túlcsordulásmentes mérést biztosít.
- **Interfész-szűrés:** Zéró duplikáció – automatikusan kiszűri a virtuális VPN (`utun*`) és AirDrop (`awdl0`) csatornákat.
- **Reboot- és PDP-reset védelem:** Intelligens deltaméréssel kezeli az iOS bázissáv és a telefon újraindulásait.

### 2. 🌊 Élő Adatfolyam (Live Traffic Stream)
- **Node & Particle Flow:** A Home Assistant és Tesla energiaáramlási dashboardok mintájára valós időben jeleníti meg az adatok utazását a forrásoktól (Mobilnet, Wi-Fi) az iPhone hálózati magján át a célállomások felé.
- **120 Hz ProMotion Metal Canvas:** SwiftUI `Canvas` és `TimelineView` motorral animált Bezier pályák, ahol a fénygömbök sebessége közvetlenül arányos a mért sávszélességgel.
- **Transzparens Célállomások:** Különválasztja a felismert szolgáltatásokat (Apple CDN, WebKit, Reklámok) és az egyéb titkosított alkalmazásforgalmat (*Untracked consumption*).

### 3. 🏝️ Dynamic Island & Lock Screen Élő Követés (`ActivityKit`)
- **Kompakt nézetek:** Rádióantenna üvegjelvény bal oldalon, élő gigabájt számláló jobb oldalon.
- **Kibontott (Expanded) Island:** Érintésre lenyíló mini műszerfal kapacitássávval, fordulónap-előrejelzéssel és pillanatnyi sebességgel.
- **Zárolási Képernyő & StandBy:** Always-On Display támogatás valós idejű telemetriával.

### 4. 📉 Burn Down Chart & 2026 Keretkimerülési Előrejelzés (Forecast)
- A szoftverfejlesztésből ismert burn down görbével mutatja a havi adatkeret optimális és tényleges fogyását.
- Burn rate sebességmérő, amely naptári napra pontosan előrejelzi, hogy a keret kitart-e a fordulónapig.

### 5. 🧩 Teljes WidgetKit Csomag
- **Small Widget:** 26 pt-es kerek üvegjelvény, split hero tipográfia (`13.92 GB`), dinamikus energiasáv és `✓ Fordulóig kitart` kapszula.
- **Medium & Large Widgetek:** Részletes analitika, Wi-Fi és Mobilnet forgalom, valamint a Scout kabala állapota.
- **Lock Screen / StandBy Widgetek:** Helytakarékos körkörös és téglalap alakú kiegészítők.

---

## 📐 Verziókezelési Szabályzat (Semantic Versioning)

A projekt a [Semantic Versioning 2.0](VERSIONING.md) szabályrendszerét követi:

- **`1.0.x` (Patch):** Kisebb hibajavítások, stabilitási finomítások, apróbb UI igazítások.
- **`1.x.0` (Minor):** Nagyobb módosítások, javítások és új funkciók (pl. új nézetek, widgetek).
- **`x.0.0` (Major):** Főverzió, mélyreható architekturális változás (**kizárólag külön felhasználói engedéllyel!**).

Verzióléptetés automatikusan a `./scripts/bump_version.sh` segítségével:
```bash
./scripts/bump_version.sh patch   # 1.0.0 -> 1.0.1
./scripts/bump_version.sh minor   # 1.0.1 -> 1.1.0
./scripts/bump_version.sh major --confirm  # Főverzió léptetés
```

---

## 🛠️ Telepítés és Fejlesztés

A projekt konfigurációját a deklaratív [XcodeGen](https://github.com/yonaskolb/XcodeGen) kezeli:

```bash
# 1. Xcode projekt generálása
xcodegen generate

# 2. Egységtesztek futtatása
xcodebuild test -scheme DataScout -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# 3. Fordítás és futtatás fizikai eszközön
xcodebuild build -scheme DataScout -destination 'id=<DEVICE_UDID>'
```

---

## 🔒 Felelős Adatkezelés

A DataScout az Apple iOS szigorú adatvédelmi irányelvei (App Store Guideline 5.4) szerint működik. Lakossági eszközökön az iOS Sandbox védi más appok belső folyamatait: a hardveres összegzett mérések 100%-osak a Darwin kernelből, a célállomások heurisztikusan és transzparensen jelennek meg.
