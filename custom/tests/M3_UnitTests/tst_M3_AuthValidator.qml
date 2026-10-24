import QtQuick
import QtTest
import PulseGCS

TestCase {
    id: testCase
    name: "M3_AuthValidatorQuickTest"

    // -------------------------------------------------------------------------
    // 1. Data-driven Email Validation
    // -------------------------------------------------------------------------
    function test_email_data() {
        return [
            { tag: "empty", email: "", expected: false },
            { tag: "whitespace", email: "   ", expected: false },
            { tag: "missing_@", email: "pilot.example.com", expected: false },
            { tag: "missing_domain", email: "pilot@", expected: false },
            { tag: "valid_standard", email: "pilot@example.com", expected: true },
            { tag: "valid_subdomain", email: "pilot@ops.skyx.aero", expected: true },
            { tag: "valid_plus", email: "pilot+drone@example.com", expected: true }
        ]
    }

    function test_email(data) {
        var res = PulseGCSAuthValidator.validateEmail(data.email)
        compare(res.valid, data.expected, "Email validation for: " + data.tag)
    }

    // -------------------------------------------------------------------------
    // 2. Data-driven Password Validation
    // -------------------------------------------------------------------------
    function test_password_data() {
        return [
            { tag: "empty", pw: "", expected: false },
            { tag: "short", pw: "1234567", expected: false },
            { tag: "8_chars", pw: "12345678", expected: true },
            { tag: "strong", pw: "FlightOps2026!#", expected: true }
        ]
    }

    function test_password(data) {
        var res = PulseGCSAuthValidator.validatePassword(data.pw)
        compare(res.valid, data.expected, "Password validation for: " + data.tag)
    }

    // -------------------------------------------------------------------------
    // 3. 6-Digit Monospace Recovery Code
    // -------------------------------------------------------------------------
    function test_recoveryCode() {
        compare(PulseGCSAuthValidator.validateRecoveryCode("12345").valid, false, "5 digits rejected")
        compare(PulseGCSAuthValidator.validateRecoveryCode("ABCDEF").valid, false, "Alpha rejected")
        compare(PulseGCSAuthValidator.validateRecoveryCode("123456").valid, false, "Non-matching rejected")
        compare(PulseGCSAuthValidator.validateRecoveryCode("849201").valid, true, "Authoritative code 849201 accepted")
    }

    // -------------------------------------------------------------------------
    // 4. Operator Registration Step 1 & Step 2 Validators
    // -------------------------------------------------------------------------
    function test_registrationFields() {
        compare(PulseGCSAuthValidator.validateFullName("A").valid, false, "Too short name rejected")
        compare(PulseGCSAuthValidator.validateFullName("Alex Rivera").valid, true, "Valid name accepted")
        compare(PulseGCSAuthValidator.validatePhone("123").valid, false, "Too short phone rejected")
        compare(PulseGCSAuthValidator.validatePhone("+1-555-0199").valid, true, "Valid phone accepted")
        compare(PulseGCSAuthValidator.validateDroneSerial("AB").valid, false, "Too short serial (< 3) rejected")
        compare(PulseGCSAuthValidator.validateDroneSerial("SKYX-VTOL-8842").valid, true, "Valid drone serial accepted")
        compare(PulseGCSAuthValidator.validateConsoleBinding(false).valid, false, "Unchecked console binding rejected")
        compare(PulseGCSAuthValidator.validateConsoleBinding(true).valid, true, "Checked console binding accepted")
    }
}

