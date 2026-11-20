# domusius_app

Cross-platform Flutter client for **Domusius** – a modular home management and energy tracking platform connected to a PHP/MySQL backend (`system/modules/<module>/api/`).

## Features

- **Dynamic module rendering:** Loads views, stats cards, forms, and tables dynamically from each module's `api.php` endpoint.
- **Electric Vehicle (EV) module:** Supports multiple vehicles (`elbiler`), logging charging sessions (`elbil_opladning`) with kWh, price (`DKK`), timestamp, source (`APP`), location (`Home` / `Out`), and odometer (`km_stand`), plus recent charging history across vehicles.
- **Modular architecture:** New modules can be added on the backend without hardcoding module names or endpoints in the UI.

## Network & Configuration

- Designed to connect to your self-hosted backend (for example over **Tailscale** or local/remote HTTPS).
- Keep local server URLs, credentials, and environment-specific settings out of version control.

## Getting Started

1. Ensure your **Domusius** PHP/MySQL backend is running and reachable from your device/emulator.
2. Configure your backend base URL in the app.
3. Install dependencies and run the app:

```bash
flutter pub get
flutter run
