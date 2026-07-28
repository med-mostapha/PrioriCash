# PrioriCash

A personal financial assistant for people with irregular income — reserving
money for commitments **before** it can be spent.

Built with Flutter, Riverpod, and Drift (SQLite). Offline-first, no backend.

---

## The problem

Mainstream budgeting apps assume a fixed monthly salary. PrioriCash doesn't.
Income arrives unpredictably (a delayed grant, family support, freelance
work), and the app's one job is answering, at any moment:

> **"How much of this money is actually mine to spend right now?"**

It does this by tracking three numbers, always:

```
Total balance  -  Reserved for commitments  =  Available to spend
```

`Available` can be **negative** — and the app shows that honestly, never
clamped to zero. A negative available balance is the single most important
signal the app can give.

---

## Documentation

| File                  | What it's for                                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `SmartWallet_SRS.pdf` | Requirements — R1 through R20, use cases, data model, architecture                                                  |
| `BACKLOG.md`          | Sprint 1 backlog and day-by-day plan (historical — Sprint 1 is complete)                                            |
| `AGENTS.md`           | **Read this before writing any code.** Non-negotiable rules for any AI assistant working on this repo               |
| `DOCS.md`             | **Current project status.** What's built, what's next, known gaps — read this to pick up where the project left off |

If you're an AI assistant starting a new session on this project, read
`AGENTS.md` and `DOCS.md` in full before touching any code.

---

## Getting started

```bash
flutter pub get
dart run intl_utils:generate    # regenerates lib/generated/ from lib/l10n/*.arb
dart run build_runner build --delete-conflicting-outputs   # regenerates Drift's *.g.dart
flutter test
flutter run
```

`lib/generated/` and `*.g.dart` files are gitignored — they're reproducible
from `lib/l10n/*.arb` and `lib/data/database/tables.dart` respectively, and
must be regenerated after every clone.

### Running on a specific device

```bash
flutter devices
flutter run -d <device-id>
```

### Testing in Arabic

The app supports English and Arabic (RTL) fully. To test Arabic: change the
device's system language to Arabic (Settings -> Languages) and relaunch the
app — there's no in-app language switch yet.

---

## Project structure

```
lib/
├── domain/          Pure Dart. No Flutter, no Drift, no I/O. Fully unit-tested.
│   ├── value_objects/   Money, Recurrence
│   ├── entities/         Obligation, ObligationInstance, Allocation, SavingsGoal
│   ├── services/         AllocationEngine, BalanceCalculator, InstanceGenerator, PurchaseAdvisor
│   └── repositories/     Abstract repository interfaces
├── data/
│   ├── database/         Drift schema (tables.dart) + AppDatabase
│   └── repositories/     Drift implementations of the domain interfaces
└── presentation/
    ├── theme/            AppColors, AppTypography, AppSpacing, AppTheme — single source of design tokens
    ├── widgets/           Reusable display components
    ├── screens/           HomeScreen, ObligationListScreen, ObligationFormScreen, DebugScreen
    ├── providers/         Riverpod wiring
    └── utils/              MoneyFormat

lib/l10n/            intl_en.arb, intl_ar.arb — source of truth for every user-facing string

test/
├── domain/            Unit tests, zero I/O, zero Flutter
└── data/               Repository and schema tests against a real (in-memory) SQLite database
```

---

## Key architectural decisions

These are locked — changing any of them means updating `AGENTS.md` and the
SRS first, not just the code:

- **Money is `int` in minor units, never `double`.** MRU follows ISO 4217
  exponent 2 (100 minor units per major), not its formal 1:5 khoums ratio —
  khoums are no longer in circulation.
- **Reservation horizon is 30 days**, and the reservation query has **no
  lower date bound** — overdue commitments are always included, which is
  what makes accumulated overdue amounts get funded before future ones.
- **Allocation is a ledger**, append-only. Undo reverses, never deletes.
- **No polymorphic FK.** The allocation table uses two nullable foreign
  keys (`instance_id`, `goal_id`) plus a `CHECK` constraint instead — SQLite
  can't enforce referential integrity on a polymorphic column.
- **No hardcoded design values or strings in `lib/presentation/`.** Every
  color/size/spacing comes from `lib/presentation/theme/`; every string
  comes from `S.of(context)`. See `AGENTS.md` sections 2.4-2.6.
- **Full Arabic/English support from day one**, RTL included. This is not
  an afterthought — see `AGENTS.md` section 2.6.

---

## License

Not yet decided. This is a personal project in active development.
