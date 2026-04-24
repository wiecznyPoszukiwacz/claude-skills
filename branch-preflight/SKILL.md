---
name: branch-preflight
description: Sprawdza, czy repozytorium Git jest gotowe do utworzenia nowego brancha z wybranego brancha bazowego (domyślnie develop). Używaj przed każdą akcją typu "odgałęź nowy branch" — w tym wewnątrz /start-work. Skill wykonuje tylko kontrole nie-destrukcyjne (status, log, fetch) i odmawia wejścia w fazę tworzenia brancha, jeśli któryś z warunków nie jest spełniony.
---

# branch-preflight — preflight repozytorium przed utworzeniem nowego brancha

Zadaniem skilla jest jednoznaczne stwierdzenie: **"tak, można bezpiecznie odgałęzić nowy branch"** albo **"NIE — oto dokładnie co blokuje i jak to naprawić"**. Nie tworzy brancha. Nie modyfikuje stanu repozytorium poza `git fetch --prune --all`.

## Wykonanie

Źródłem prawdy wszystkich kontroli jest skrypt `preflight.sh` obok tego pliku. Nie duplikuj jego logiki w rozumowaniu — po prostu go uruchom:

```bash
./preflight.sh [--base <branch>] [--new-branch <nazwa>]
```

- `--base` — branch bazowy (domyślnie `develop`). Sprawdzany jako `origin/<base>`.
- `--new-branch` — *opcjonalnie* planowana nazwa nowego brancha. Jeśli podana, skrypt sprawdzi, że nie istnieje lokalnie ani zdalnie.

Exit code `0` oznacza OK. Każdy inny — odmowa; powód i sugerowany fix trafiają na `stdout`.

## Interpretacja wyjścia

### Sukces (exit 0)

```
✅ branch-preflight: OK
  repo:      <ścieżka>
  current:   <branch> @ <short-sha>  (upstream: <upstream lub "-">)
  base:      origin/<base> @ <short-sha>
  new:       <new_branch lub "-">
```

Caller (np. `/start-work`) kontynuuje tworzenie brancha.

### Odmowa (exit ≠ 0)

Pojedyncza linia w formacie: `❌ <powód>. Fix: <komenda>`.

Przekaż ją użytkownikowi **dosłownie** — nie parafrazuj, nie dodawaj alternatywnych rozwiązań, nie proponuj `git reset --hard`, `git checkout .`, `git clean -fd`, `--no-verify` ani niczego destrukcyjnego. Decyzję o takich operacjach podejmuje user.

## Zakres kontroli (kontrakt)

Szczegółowa logika — w `preflight.sh`. Tu tylko lista kategorii, na które można się powoływać w komunikacji z użytkownikiem:

1. **Sanity repo** — jesteśmy w repo, istnieje remote, HEAD nie jest detached.
2. **Brak operacji w toku** — żaden merge / cherry-pick / revert / rebase.
3. **Czystość working copy** — brak staged/unstaged/untracked, pusty stash.
4. **Submoduły** — wszystkie zainicjalizowane i czyste.
5. **Git LFS** — jeśli repo go używa, `git-lfs` musi być zainstalowane.
6. **Upstream bieżącego brancha** — zsynchronizowany z remote (jeśli upstream istnieje); brak upstream + istniejące commity → odmowa.
7. **Gotowość brancha bazowego** — po `git fetch --prune --all` istnieje `origin/<base>`.
8. **Kolizja nazwy** — jeśli podano `--new-branch`, nie istnieje lokalnie ani zdalnie.

## Twarde zasady

- Skrypt **nie tworzy** brancha, nie pushuje, nie commitu je, nie stashuje.
- Jedyną dozwoloną operacją zapisującą jest `git fetch --prune --all`.
- Nigdy nie modyfikuj powodu odmowy ani nie proponuj destrukcyjnych fixów.
- Jeśli `git` (lub `git-lfs`, gdy wymagane) nie jest dostępny → skrypt odmawia.

## Użycie z innych skills / komend

`/start-work` i podobne komendy delegują całość "Git safety checks" do tego skilla, wywołując skrypt z `--base develop` i planowaną nazwą brancha. Dopiero po exit code `0` wykonują `git checkout -b` i `git push -u`.
