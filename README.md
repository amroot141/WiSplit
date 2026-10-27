# ⚡ WiSplit — Minimalist Offline-First Expense Splitting & Debt Simplification

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.29.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-black)](https://github.com/amroot141/WiSplit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Download_APK-v1.0.0-BFA2FA?style=for-the-badge&logo=android&logoColor=black)](https://github.com/amroot141/WiSplit/raw/main/WiSplit-release.apk)

<p align="center">
  <b>A distraction-free, pure OLED fintech ledger engineered for effortless expense sharing, minimum cash flow debt simplification, and offline-first reliability. Built strictly in Indian Rupees (₹).</b>
</p>

[📲 **Download Latest Release APK**](https://github.com/amroot141/WiSplit/raw/main/WiSplit-release.apk) • [📦 **GitHub Releases**](https://github.com/amroot141/WiSplit/releases) • [📖 **Architecture**](#-system-architecture) • [🚀 **Getting Started**](#-getting-started)

</div>

---

## 📥 Download & Installation

You can download and install the Android build directly:

### 👉 [Download WiSplit Release APK (v1.0.0)](https://github.com/amroot141/WiSplit/raw/main/WiSplit-release.apk)
*(File size: ~63.6 MB • Target: Android 8.0+ / API 26+)*

> [!NOTE]
> **Installing on Android (Play Protect Notice)**:
> Because this is a self-signed release build not distributed via the Google Play Store, Android Play Protect will display a prompt during installation.
> 1. Tap **"More details"** (or disable Play Protect in Google Play settings).
> 2. Tap **"Install anyway"** to complete the installation.

---

## ✨ Key Features

### 1. 💸 Direct Group Payments ("A paid B ₹300")
- Record direct 1-to-1 payments within any group with zero placeholders or dummy data.
- Automatically adjusts member balances and resolves simplified debt allocations in real-time.
- Supports optional notes and custom transfer timestamps.

### 2. 🕒 Automatic & Editable Timestamps
- Every added expense or recorded payment automatically captures the current date and time (`DateTime.now()`).
- Inline interactive Date & Time pickers allow you to edit the exact timestamp before saving.
- Full timestamps (e.g., `27/10/2026 at 19:30`) are preserved across local SQLite storage and cloud synchronization.

### 3. 📊 Spreadsheet Import & Export (Excel, CSV, TSV)
- **Import from Settings**: Dedicated **Data Management & Import** card in Profile & Settings to load expense files into any selected group.
- **Group AppBar Import**: One-tap upload from the group header.
- **Supported Formats**: Excel workbooks (`.xlsx`, `.xls`), CSV (`.csv`), TSV (`.tsv`), and plain text.
- **Preview & Verification**: Shows detected rows count and total ₹ amount before confirming batch creation.
- **Export**: Export expenses to CSV or download formatted text summary reports.

### 4. 🧮 Greedy Debt Simplification
- Implements bipartite debt simplification to reduce $O(N^2)$ cross-debts down to minimum cash flows.
- Visual **"Who Owes Whom"** cards indicate exact debtors, creditors, and balances in INR (₹).
- One-tap UPI payment launcher and balance settlement triggers.

### 5. 🌑 Pure OLED Fintech Aesthetics
- Designed for AMOLED displays: Deep black (`#000000`), subtle dark containers, and soft lavender accents (`#BFA2FA`).
- Typography-first layout using Google Outfit & Inter with smooth micro-animations.
- No dummy/placeholder groups or sample data — 100% real ledger state.

### 6. 📴 Offline-First Resilience & Sync Queue
- Powered by local SQLite (`sqflite`). All reads and writes execute with zero network latency.
- Mutation queue automatically enqueues offline operations and seamlessly pushes changes when connectivity is restored.

### 7. 📱 Hardware Sensor & Shortcut Triggers
- Configurable quick-entry shortcuts: Back double-tap, back triple-tap, phone shake, or triple power-key triggers.
- Customizable sensor sensitivity (Low, Medium, High).

---

## 🏛 System Architecture

WiSplit is structured as a decoupled client-server architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                     WiSplit Flutter App                     │
│  (Riverpod 2.0 • SQLite Cache • OLED Fintech Design System) │
└──────────────┬──────────────────────────────┬───────────────┘
               │ (Offline Writes)             │ (REST / JSON)
               ▼                              ▼
      ┌──────────────────┐          ┌───────────────────┐
      │  Local SQLite    │          │  FastAPI Backend  │
      │  & Sync Queue    │          │  (Python 3.11+)   │
      └──────────────────┘          └─────────┬─────────┘
                                              │
                                              ▼
                                    ┌───────────────────┐
                                    │ Supabase Postgres │
                                    │ (Auth & Database) │
                                    └───────────────────┘
```

---

## 📂 Repository Structure

```
WiSplit/
├── WiSplit-release.apk           # Pre-compiled release APK for direct download
├── app/                          # FastAPI Backend
│   ├── config.py                 # Supabase & app configuration
│   ├── main.py                   # FastAPI application entrypoint
│   ├── routers/
│   │   ├── auth.py               # Signup, signin, OTP verification
│   │   ├── expenses.py           # Expense CRUD & split calculations
│   │   ├── groups.py             # Group creation & membership
│   │   ├── personal_ledger.py    # Personal offline balance sync
│   │   └── settlements.py        # Debt simplification endpoint
│   ├── schemas.py                # Pydantic models & validators
│   └── services/
│       ├── debt_simplifier.py    # Backend debt simplification algorithm
│       └── split_calculator.py   # Penny-perfect split computation
├── client/                       # Flutter Mobile Client
│   ├── lib/
│   │   ├── core/
│   │   │   ├── algorithms/       # Client-side debt simplifier
│   │   │   ├── database/         # SQLite tables & offline sync queue
│   │   │   ├── hardware/         # Android Back-Tap platform channel
│   │   │   ├── network/          # HTTP client & connectivity monitor
│   │   │   ├── services/         # ImportService (Excel/CSV) & ExportService
│   │   │   └── theme/            # OLED AppColors & AppTypography
│   │   ├── data/                 # Models, repositories, and API services
│   │   └── presentation/         # Riverpod providers, screens & widgets
│   ├── android/                  # Android Gradle build configuration
│   └── pubspec.yaml              # Flutter dependencies (file_picker, excel, riverpod)
├── .github/workflows/
│   └── build-apk.yml             # GitHub Actions CI/CD to build & release APK
├── schema.sql                    # Supabase PostgreSQL database schema
├── requirements.txt              # Python server dependencies
└── README.md                     # Documentation
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.10.0`
- **Android SDK**: API 34+
- **Python**: `>= 3.10`
- **Supabase Account** (or local Postgres instance)

---

### Backend Setup (FastAPI)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/amroot141/WiSplit.git
   cd WiSplit
   ```

2. **Configure environment variables**:
   Create a `.env` file based on `.env.example`:
   ```ini
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_KEY=your_supabase_anon_or_service_key
   JWT_SECRET=your_jwt_secret_key
   PORT=8000
   ```

3. **Install Python dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Initialize Database**:
   Execute `schema.sql` inside your Supabase SQL Editor.

5. **Start server**:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

---

### Client Setup (Flutter)

1. **Navigate to the client directory**:
   ```bash
   cd client
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on connected device/emulator**:
   ```bash
   flutter run
   ```

4. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```
   The output will be generated at `client/build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
