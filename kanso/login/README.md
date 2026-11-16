# Kanso Login · Plasma Login Manager

Bezpečný doplněk pro **Kanso V3.4** na CachyOS / KDE Plasma 6. Nemění Quickshell, display manager, hesla, PAM ani automatické přihlášení.

## Co dokáže

- Nastaví přihlašovací obrazovku na **původní Kanso tapetu** (Day nebo Night).
- Zkopíruje obě tapety do `/usr/local/share/kanso-login/`, protože přihlašovací obrazovka nemusí mít přístup do `~/Rice/`.
- Nastaví barvy přihlašovacího prostředí na `KansoInk` / `KansoNight` v konfiguračních souborech účtu `plasmalogin`. Výsledek závisí na konkrétní verzi Plasma Login Manageru.
- Zazálohuje všechny měněné systémové soubory do `/var/lib/kanso-login/` (přístup má jen root).
- Podporuje **kontrolu bez změn** a **obnovu**; pokud byly soubory mezitím upraveny jiným programem, odmítne je přepsat.

**Co nedokáže:** Plasma Login Manager (na rozdíl od SDDM) nepodporuje vlastní kompletní QML přihlašovací motiv. Rozmístění a chování přihlašovacích polí zůstává nativní KDE. Nejde o tematický fork a nijak nemění autentizaci.

## Instalace do existujícího Kansa

Stáhni `Kanso-Login.zip` do `~/Downloads` a spusť:

```fish
unzip -o ~/Downloads/Kanso-Login.zip -d ~/Rice
python3 ~/Rice/kanso/login/kanso_login.py status
python3 ~/Rice/kanso/login/kanso_login.py apply --mode auto --dry-run
sudo python3 ~/Rice/kanso/login/kanso_login.py apply --mode auto
```

Volba `auto` přečte `~/Rice/kanso/theme-selection.json` a použije Day/Night. Tento režim se **nepřepíná automaticky** pokaždé, když klikneš na měsíc/slunce; po změně režimu Kansa se dá přihlašovací obrazovka synchronizovat znovu stejným příkazem.

**Bezpečný test:** ulož práci a **odhlas se**. Nerestartuj službu display manageru (`systemctl restart ...` by ukončil aktuální grafickou relaci).

## Ruční přepnutí

```fish
sudo python3 ~/Rice/kanso/login/kanso_login.py apply --mode night
sudo python3 ~/Rice/kanso/login/kanso_login.py apply --mode day
```

## Vrácení původní přihlašovací obrazovky

```fish
sudo python3 ~/Rice/kanso/login/kanso_login.py restore
```

Tento příkaz vrací původní konfigurační soubory včetně ostatních nastavení přihlašování, jejich obsahu a práv. Po úspěšné obnově zůstanou záložní soubory pod `/var/lib/kanso-login/` pro případ kontroly.

Pokud KDE mezitím změnilo přihlašovací konfiguraci, skript ji odmítne automaticky přepsat. Před obnovou porovnej zálohu s aktuálními soubory.

## Omezení a poznámky

- Funguje jen, pokud je aktivní služba **plasmalogin**. Pokud je aktivní **SDDM**, nic nepřepisuje; SDDM potřebuje jiný typ tématu.
- KDE má v roce 2026 zdokumentované chyby při ukládání tapety v dialogu „Přihlašovací obrazovka“. Po instalaci zde raději nenastavuj jinou tapetu; pokud ji přesto změníš, skript zaznamená konflikt a odmítne původní soubor přepsat.
- Správce přihlášení používá vlastní účet. Proto se barvy mohou u některých verzí KDE aplikovat odlišně od barev uživatelské plochy.
- Žádný skript nespouštěj jako root z nedůvěryhodného archivu. Zdrojový kód můžeš před instalací celý přečíst v `~/Rice/kanso/login/kanso_login.py`.
- Starý Amber ani Crylii nemaž jen kvůli tomuto doplňku; samotné Kanso Login na jejich souborech nezávisí.

## Testy

`python3 -m unittest discover -s tests -v` v rozbaleném zdrojovém archivu provádí izolované testy INI úprav, režimů, záloh, obnovy a detekce konfliktu bez zásahu do skutečných systémových souborů.
