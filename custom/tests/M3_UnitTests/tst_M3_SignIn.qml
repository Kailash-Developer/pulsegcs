import QtQuick
import QtTest
import PulseGCS

TestCase {
    id: testCase
    name: "M3_SignInQuickTest"
    width: 600
    height: 800
    visible: true
    when: windowShown

    // Component under test
    PulseGCSSignInCard {
        id: signInCard
        anchors.centerIn: parent
        width: 380
    }

    PulseGCSAuthService {
        id: authService
        mockMode: true
    }

    // Signal Spies
    SignalSpy {
        id: signInSpy
        target: signInCard
        signalName: "signInRequested"
    }

    SignalSpy {
        id: noticeSpy
        target: signInCard
        signalName: "noticeRequested"
    }

    SignalSpy {
        id: demoSpy
        target: signInCard
        signalName: "demoModeRequested"
    }

    SignalSpy {
        id: registerSpy
        target: signInCard
        signalName: "registerRequested"
    }

    SignalSpy {
        id: forgotSpy
        target: signInCard
        signalName: "forgotPasswordRequested"
    }

    function cleanup() {
        signInSpy.clear()
        noticeSpy.clear()
        demoSpy.clear()
        registerSpy.clear()
        forgotSpy.clear()
        signInCard.email = ""
        signInCard.password = ""
    }

    // -------------------------------------------------------------------------
    // 1. Initial State & Property Invariants
    // -------------------------------------------------------------------------
    function test_initialCardState() {
        verify(signInCard !== null, "SignIn card instance created")
        compare(signInCard.email, "", "Initial email is empty")
        compare(signInCard.password, "", "Initial password is empty")
        compare(signInSpy.count, 0, "No sign-in signal emitted initially")
    }

    // -------------------------------------------------------------------------
    // 2. Navigation Signals (Demo Mode, Register, Forgot Password)
    // -------------------------------------------------------------------------
    function test_navigationSignals() {
        signInCard.demoModeRequested()
        compare(demoSpy.count, 1, "demoModeRequested emitted on Demo Mode click")

        signInCard.registerRequested()
        compare(registerSpy.count, 1, "registerRequested emitted on Register link click")

        signInCard.forgotPasswordRequested()
        compare(forgotSpy.count, 1, "forgotPasswordRequested emitted on Forgot Password click")
    }

    // -------------------------------------------------------------------------
    // 3. Validation Guards (Empty Email & Short Password Rejection)
    // -------------------------------------------------------------------------
    function test_emptyCredentialsValidation() {
        signInCard.email = ""
        signInCard.password = ""

        var emailCheck = PulseGCSAuthValidator.validateEmail(signInCard.email)
        compare(emailCheck.valid, false, "Empty email rejected")
        verify(emailCheck.error.length > 0, "Error message provided for empty email")

        var pwCheck = PulseGCSAuthValidator.validatePassword(signInCard.password)
        compare(pwCheck.valid, false, "Empty password rejected")
    }

    function test_invalidEmailFormatValidation() {
        signInCard.email = "not-an-email"
        var emailCheck = PulseGCSAuthValidator.validateEmail(signInCard.email)
        compare(emailCheck.valid, false, "Invalid format email rejected")
    }

    function test_shortPasswordValidation() {
        signInCard.password = "short"
        var pwCheck = PulseGCSAuthValidator.validatePassword(signInCard.password)
        compare(pwCheck.valid, false, "Password < 8 chars rejected")
    }

    // -------------------------------------------------------------------------
    // 4. Valid Sign In Signal Emission & Parameter Matching
    // -------------------------------------------------------------------------
    function test_validSignInEmission() {
        signInCard.email = "pilot@example.com"
        signInCard.password = "FlightPass2026!"

        var emailCheck = PulseGCSAuthValidator.validateEmail(signInCard.email)
        compare(emailCheck.valid, true, "Email validation passes")

        var pwCheck = PulseGCSAuthValidator.validatePassword(signInCard.password)
        compare(pwCheck.valid, true, "Password validation passes")

        signInCard.signInRequested(signInCard.email, signInCard.password)
        compare(signInSpy.count, 1, "signInRequested emitted successfully")
        compare(signInSpy.signalArguments[0][0], "pilot@example.com", "First argument is email")
        compare(signInSpy.signalArguments[0][1], "FlightPass2026!", "Second argument is password")
    }
}

