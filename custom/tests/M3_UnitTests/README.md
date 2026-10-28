# PulseGCS Milestone 3: Authentication & Operator Flow Unit Tests

This directory contains the upstream-style **Qt Quick Test** suite (`QtTest` / `TestCase` / `SignalSpy`) for Milestone 3 (Authentication, Registration, and Password Recovery).

All tests execute natively through Qt's `qmltestrunner` in an offscreen headless environment.

---

## Directory Structure

```text
custom/tests/M3_UnitTests/
├── README.md                      # This documentation
├── run_m3_tests.sh                # Execution script (runs all suites via qmltestrunner)
├── tst_M3_AuthValidator.qml       # Centralized field validators (RFC 5322, 6-digit code, serials)
├── tst_M3_SignIn.qml              # Sign-In card & navigation signals (M3-US01)
├── tst_M3_Registration.qml        # 2-Step Registration wizard & console binding (M3-US02)
├── tst_M3_PasswordRecovery.qml    # 3-Stage Password Recovery & cancel-loop invariants (M3-US03)
├── tst_M3_AuthService.qml         # REST client, endpoint schemas & Mock Backend engine (US07/US08/US09/US11)
├── tst_M3_StoriesCompletion.qml   # Flow & modal tests for US07, US08, US09, US11
└── tst_M3_DemoMode.qml            # Headless Demo Mode FSM, arming interlocks & hazard banner (M3-US10)
```

---

## Test Suites Overview

### 1. `tst_M3_AuthValidator.qml` — Centralized Input Validators
* **Email Validator:** Data-driven table verifying RFC 5322 compliance, whitespace trimming, subdomains, plus-tags, and rejection of invalid characters or double dots.
* **Password Validator:** Enforces minimum 8-character length and presence.
* **6-Digit Recovery Code:** Verifies monospace numeric constraints and accepts the authoritative test code (`849201`).
* **Operator Fields:** Full Name ($\ge 2$ chars), Phone ($\ge 7$ digits), DOB (`DD / MM / YYYY`).
* **Drone Hardware Fields:** Aircraft serial number ($\ge 3$ chars) and flight console binding checkbox.

### 2. `tst_M3_SignIn.qml` — Operator Sign-In (M3-US01)
* **Component Initialization:** Verifies initial clean state, blank input fields, and 0 signal counts.
* **Navigation Signal Routing:**
  - `demoModeRequested()` &rarr; Emitted on Demo Mode button click.
  - `registerRequested()` &rarr; Emitted on *"Sign Up"* navigation link.
  - `forgotPasswordRequested()` &rarr; Emitted on *"Forgot Password"* link.
* **Input Validation Guards:** Rejects empty email, invalid email format, and passwords $< 8$ characters.
* **Valid Sign-In Emission:** Verifies `signInRequested(email, password)` with argument parity using `SignalSpy`.

### 3. `tst_M3_Registration.qml` — 2-Step Customer Registration (M3-US02)
* **Step State Machine:**
  - Starts on `currentStep = 1` (Operator Information).
  - Validates full name, phone, email, password, and date of birth.
* **Step 2 Transition & Data Preservation:**
  - Advances to `currentStep = 2` (Aircraft & Console Binding).
  - Tapping **"‹ Back"** in Step 2 transitions back to Step 1 **without losing any entered data**.
* **Hardware Binding & Submission:**
  - Enforces visible drone serial number.
  - Enforces flight console binding confirmation checkbox.
  - Emits `applicationSubmitted(regData)` with full hardware + operator payload.
* **Reset Form Invariants:** `resetForm()` restores clean initial defaults.

### 4. `tst_M3_PasswordRecovery.qml` — 3-Stage Password Recovery (M3-US03)
* **3-Stage State Machine:**
  - Stage 1: Registered email input & validation.
  - Stage 2: 6-digit monospace verification code input.
  - Stage 3: New password and confirm password matching.
* **Resend Code Action:** Clicking **"Resend Code"** clears the 6-digit input box so the user can enter the newly dispatched code.
* **Cancel Loop Invariants:** Tapping **"‹ Back"** or **"Cancel"** at any stage wipes the verification code, wipes passwords, and resets cleanly to Stage 1 (`recoveryStage = "request"`).

### 5. `tst_M3_AuthService.qml` — Backend REST & Mock Contract
* **Endpoints Schema Registry:** Verifies paths for `/api/v1/auth/signin`, `/api/v1/auth/register`, `/api/v1/auth/recovery/*`, and `/api/v1/health`.
* **Mock Engine Contract:**
  - Sign-in success: Returns HTTP 200, JWT token, and 7-day attestation window.
  - Sign-in failure: Returns HTTP 401 (Wrong password) or 404 (Unregistered user).
  - Registration: Generates `APP-XXXXXX` tracking ID in `pending_verification` state.
  - Password recovery: Simulates 6-digit code `849201`, issues single-use `resetToken`, and completes password update.

### 6. `tst_M3_DemoMode.qml` — Isolated Demo Access & Safety Interlocks (M3-US10)
* **UI Independence:** Simulation state and MockLink lifecycle are decoupled into `PulseGCSDemoModeManager`, allowing future FlyView and PlanView redesigns without altering demo logic.
* **Safety & Arming Interlocks:**
  - `allowRealHardwareArming`: Evaluates strictly to `false` when in Demo Mode.
  - `suppressLiveScanning`: Evaluates to `true` to block physical Bluetooth and RF discovery.
  - `canArmAircraft()`: Centralized safety check returning `false` during simulation.
* **Hazard Banner Lifecycle:** Verifies `PulseGCSDemoBanner` visibility and dynamic height collapse upon start/stop.
* **Idempotency & Signals:** Verifies single-emission invariants for `demoModeStarted` and `demoModeStopped`.

### 7. `tst_M3_StoriesCompletion.qml` — Feature Flow Verification (US07, US08, US09, US11)
* **M3-US07 (License Key Activation Modal):** Verifies modal opening, reference data fields (`SKYX-LIC-8820-4190-FA21`, `SkyX Kissan`, `SKYX-KSN-2026-0842`), and clipboard copy action feedback.
* **M3-US08 (7-Day Session Vault & Expiration):** Verifies active 7-day session token grant for standard pilots and flight console entry lockout on expired session credentials (`expired@skyx.aero`).
* **M3-US09 (FCM Silicon UID Mismatch):** Verifies telemetry connection abort and failure modal on hardware mismatch (`1A:2B:3C:4D:5E:6F` vs `SKYX-KSN-2026-0842`) across both SignInView and ConnectAircraftPanel.
* **M3-US11 (Console Suspended Lockout):** Verifies HTTP 403 suspension simulation (`suspended@skyx.aero`), descriptive error dialog, and routing to SkyX administrative support.

---

## How to Run

Execute all Milestone 3 test suites from your terminal:

```bash
bash custom/tests/M3_UnitTests/run_m3_tests.sh
```

---

## Technical Architecture

* **Engine:** Qt Quick Test (`QtTest`) via `/home/kailash/Qt/6.11.1/gcc_64/bin/qmltestrunner`.
* **Platform:** Headless offscreen (`-platform offscreen`), suitable for local development and CI/CD automation.
* **Isolation:** All test fixtures and code are isolated strictly within `custom/` per project governance rules.

