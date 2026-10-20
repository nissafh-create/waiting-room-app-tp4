# Waiting Room App - Project Summary & Documentation
## AI Collaboration History and Core Architecture Guide

---

## Part 1: AI Assistant & Interaction Summary

This section documents the AI model employed inside Antigravity and chronologically summarizes every prompt provided, the core problem identified, and the technical solution applied.

### 1. AI Model Information
- **Model Used:** Gemini 3.8 Flash (Medium)
- **Environment:** Google Antigravity Agentic IDE
- **Operating System:** Windows
- **Frameworks & Tools:** Flutter SDK, Dart, Supabase Flutter SDK, Mockito

### 2. Prompt History & Resolutions

#### Prompt 1: Fixing Missing Mockito Package
- **User Prompt:** `"Explain what this problem is and help me fix it: Target of URI doesn't exist: package:mockito/mockito.dart"`
- **Problem:** The test file imported `package:mockito/mockito.dart`, but the `mockito` package was missing from `pubspec.yaml` `dev_dependencies`.
- **Action Taken:** Executed `flutter pub add --dev mockito`, adding `mockito: ^5.6.4` to `pubspec.yaml` and resolving dependencies.

#### Prompt 2: Adding Testing Constructor to QueueProvider
- **User Prompt:** `"Create a private constructor in QueueProvider: QueueProvider._forTesting(this._supabase) : super(); add this in the right file"`
- **Problem:** `QueueProvider` hardcoded the Supabase client and lacked a constructor for dependency injection during tests.
- **Action Taken:** Updated `lib/queue_provider.dart` to declare `final SupabaseClient _supabase;` and created both `@visibleForTesting QueueProvider.forTesting(this._supabase)` and `QueueProvider._forTesting(this._supabase)`.

#### Prompt 3: Fixing Unit Test Compilation & Execution
- **User Prompt:** `"i have an error in the provider test file, what is the problem and can u fix it"`
- **Problem:** The workshop test snippet used obsolete Supabase v1 syntax (`Response` class), passed null matchers to non-nullable Dart `Object` parameters, and attempted chained `verify()` calls.
- **Action Taken:** Implemented a robust `FakeSupabaseClient` and `FakePostgrestFilterBuilder` in `test/queue_provider_test.dart` that accurately models Supabase v2's async insert chain. The test passed with 0 errors.

#### Prompt 4: Guidance on Running Tests
- **User Prompt:** `"how do i test"`
- **Action Taken:** Provided clear instructions to run tests via terminal (`flutter test test/queue_provider_test.dart`) and through IDE gutter run buttons.

#### Prompt 5: Resolving Runtime TypeError on Hot Restart
- **User Prompt:** `"Error fetching clients: TypeError: 3: type 'int' is not a subtype of type 'String'"`
- **Problem:** The database table `clients` used an integer primary key, but `Client.fromMap` expected a `String`, crashing when parsing `id: 3`.
- **Action Taken:** Modified `lib/models/client.dart` to use `id: map['id'].toString()` and updated `lib/queue_provider.dart` to compare IDs as strings during realtime delete events.

#### Prompt 6: Handling Anonymous Sign-In Error
- **User Prompt:** `"is anonymous required"` and `"comment them out"`
- **Problem:** Supabase returned `422 anonymous_provider_disabled` during startup because anonymous authentication is disabled by default in newly created Supabase projects.
- **Action Taken:** Clarified that the `clients` table policies allow public access using the `anonKey`, meaning anonymous sign-in is not strictly required. Safely commented out the `signInAnonymously()` block in `lib/main.dart`.

---

## Part 2: Application Documentation & Core Functions

The Waiting Room App is a distributed, real-time client management system. It synchronizes a live queue of waiting clients across multiple devices using Flutter for the user interface, Provider for state management, and Supabase for cloud persistence and real-time events.

### 1. `main.dart` (Application Entry Point)
- `main()`: The application entry point. Ensures Flutter widget bindings are initialized, loads environment credentials from the `.env` file using `flutter_dotenv`, initializes the Supabase client with `SUPABASE_URL` and `SUPABASE_ANON_KEY`, and wraps the app with `ChangeNotifierProvider` to supply `QueueProvider` globally.
- `WaitingRoomApp` (Widget): The primary user interface. Builds the input field for entering new client names, the Add button, the scrollable list of current clients, and the Next Client action button.

### 2. `queue_provider.dart` (State & Cloud Sync)
- `QueueProvider()`: Main constructor that immediately fetches existing clients from Supabase and establishes the real-time websocket channel.
- `QueueProvider.forTesting(this._supabase)`: Testing constructor enabling dependency injection of a mock or fake Supabase client without connecting to live network servers.
- `_fetchInitialClients()`: An asynchronous method that queries the `clients` table from Supabase ordered by creation time, converts records into `Client` objects, updates the local `_clients` list, and calls `notifyListeners()` to refresh the UI.
- `_setupRealtimeSubscription()`: Opens a Supabase Realtime websocket on `public:clients`. Listens for PostgreSQL `INSERT` events to append new clients and `DELETE` events to remove clients instantly across all connected screens without manual page refreshes.
- `addClient(String name)`: Validates that the entered name is not empty, trims whitespace, and sends an `INSERT` query to the Supabase `clients` table. When successful, the client appears across all synced devices.
- `removeClient(String id)`: Sends a DELETE request to Supabase targeting the matching client ID and removes the client from local state, triggering a UI update.
- `nextClient()`: Advances the waiting queue by selecting the first client in line and invoking `removeClient()` with their ID.
- `dispose()`: Unsubscribes and closes the Supabase Realtime channel when the provider is destroyed, preventing memory leaks.

### 3. `client.dart` (Data Model)
- `Client.fromMap(Map<String, dynamic> map)`: Factory constructor that safely maps a Supabase database row to a Dart `Client` instance. Automatically converts numeric or UUID IDs to string format and parses the timestamp into a `DateTime` object.
- `toMap()`: Serializes a Client instance into a key-value Map suitable for sending to databases or external APIs.
