# DataScout Verziókezelési Szabályzat (Semantic Versioning)

Ez a dokumentum rögzíti a **DataScout** projekt hivatalos verzióléptetési és release irányelveit.

---

## 1. Verziószámozási Struktúra (SemVer: `MAJOR.MINOR.PATCH`)

| Szint | Formátum | Leírás és Alkalmazási Terület | Jóváhagyási Szükséglet |
| :--- | :--- | :--- | :--- |
| **Patch** | **`1.0.x`** | **Kisebb hibajavítások, stabilitási finomítások:**<br>• Bugfixek és mentési hibák javítása<br>• UI elrendezési apró igazítások<br>• Címkék, formázók és szövegezések javítása<br>• Kis mértékű teljesítmény-optimalizációk | Automatikus / szokásos folyamat |
| **Minor** | **`1.x.0`** | **Nagyobb módosítások, javítások és új funkciók:**<br>• Új nézetek, képernyők (pl. Élő Adatfolyam Canvas)<br>• Új Widget méretek, ActivityKit / Dynamic Island funkciók<br>• Új statisztikai kalkulációk vagy Smart Insights modulok<br>• Jelentős UI formanyelv-frissítés | Szokásos fejlesztési folyamat |
| **Major** | **`x.0.0`** | **Architekturális mérföldkövek és gyökeres változások:**<br>• Alapvető adatmodell- vagy adatbázis-migrációk<br>• Rendszer-kompatibilitási ugrások (pl. új iOS főverzió minimumkövetelmény)<br>• Teljes újratervezett alkalmazás-architektúra | **KIZÁRÓLAG KÜLÖN ENGEDÉLLYEL!** |

---

## 2. Automatizált Verzióléptetés

A projekt gyökérkönyvtárában található `./scripts/bump_version.sh` automatikusan szinkronban tartja a `project.yml`, `Info.plist` fájlokat és a build számot:

```bash
# Aktuális verzió lekérdezése
./scripts/bump_version.sh current

# Kisebb hibajavítás (1.0.0 -> 1.0.1, Build +1)
./scripts/bump_version.sh patch

# Nagyobb javítás vagy új funkció (1.0.1 -> 1.1.0, Build +1)
./scripts/bump_version.sh minor

# Főverzió léptetés (csak külön engedéllyel!):
./scripts/bump_version.sh major --confirm
```

---

## 3. Git Release Címkék (Tags)

Minden stabil verzióhoz Git tag tartozik:
- Első kiadás: `v1.0.0`
- Következő kiadások: `v1.0.1`, `v1.1.0`, stb.
