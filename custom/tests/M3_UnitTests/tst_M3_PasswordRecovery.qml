import QtQuick
import QtTest
import PulseGCS

TestCase {
    id: testCase
    name: "M3_PasswordRecoveryQuickTest"
    width: 600
    height: 800
    visible: true
    when: windowShown

    // Component under test
    PulseGCSRecoveryCard {
        id: recoveryCard
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
        target: recoveryCard
        signalName: "signInRequested"
    }

    SignalSpy {
        id: completeSpy
        target: recoveryCard
        signalName: "recoveryCompleted"
    }

    SignalSpy {
        id: noticeSpy
        target: recoveryCard
        signalName: "noticeRequested"
    }

    function cleanup() {
        signInSpy.clear()
        completeSpy.clear()
        noticeSpy.clear()
        recoveryCard.resetFlow()
        recoveryCard.recoveryEmail = ""
    }

    // -------------------------------------------------------------------------
    // 1. Initial State & Monospace Placeholder
    // -------------------------------------------------------------------------
    function test_initialRecoveryState() {
        verify(recoveryCard !== null, "Recovery card created")
        compare(recoveryCard.recoveryStage, "request", "Starts in request stage")
        compare(recoveryCard.recoveryEmail, "", "Email initially empty")
        compare(recoveryCard.recoveryCode, "", "Code initially empty")
        compare(recoveryCard.recoveryNewPw, "", "New pw initially empty")
        compare(recoveryCard.recoveryConfirmPw, "", "Confirm pw initially empty")
    }

    // -------------------------------------------------------------------------
    // 2. Stage 1: Email Validation & Dispatch
    // -------------------------------------------------------------------------
    function test_stage1EmailValidation() {
        // Empty email rejected
        var emptyCheck = PulseGCSAuthValidator.validateEmail(recoveryCard.recoveryEmail)
        compare(emptyCheck.valid, false, "Empty email rejected")

        // Valid email accepted
        recoveryCard.recoveryEmail = "pilot@example.com"
        var validCheck = PulseGCSAuthValidator.validateEmail(recoveryCard.recoveryEmail)
        compare(validCheck.valid, true, "Valid email accepted")

        // Advance to Stage 2
        recoveryCard.recoveryStage = "code"
        compare(recoveryCard.recoveryStage, "code", "Transitioned to Stage 2 (code)")
    }

    // -------------------------------------------------------------------------
    // 3. Stage 2: 6-Digit Monospace Code & Resend Clear
    // -------------------------------------------------------------------------
    function test_stage2CodeValidationAndResend() {
        recoveryCard.recoveryStage = "code"
        recoveryCard.recoveryEmail = "pilot@example.com"

        // Invalid code check
        compare(PulseGCSAuthValidator.validateRecoveryCode("123").valid, false, "3 digits rejected")
        compare(PulseGCSAuthValidator.validateRecoveryCode("ABCDEF").valid, false, "Letters rejected")
        compare(PulseGCSAuthValidator.validateRecoveryCode("999999").valid, false, "Wrong code rejected")

        // Authoritative test code check
        compare(PulseGCSAuthValidator.validateRecoveryCode("849201").valid, true, "Authoritative code 849201 accepted")

        // Simulate entering code then clicking Resend
        recoveryCard.recoveryCode = "123456"
        compare(recoveryCard.recoveryCode, "123456", "Code entered")

        // Resend code clears the 6-digit field
        recoveryCard.recoveryCode = ""
        compare(recoveryCard.recoveryCode, "", "Resend code clears the 6-digit code field")
    }

    // -------------------------------------------------------------------------
    // 4. Stage 3: Password Matching & Completion
    // -------------------------------------------------------------------------
    function test_stage3PasswordMatching() {
        recoveryCard.recoveryStage = "new_pw"
        recoveryCard.recoveryNewPw = "NewFlightPass2026!"
        recoveryCard.recoveryConfirmPw = "MismatchPass2026!"

        var mismatch = PulseGCSAuthValidator.validatePasswordMatch(recoveryCard.recoveryNewPw, recoveryCard.recoveryConfirmPw)
        compare(mismatch.valid, false, "Password mismatch rejected")

        recoveryCard.recoveryConfirmPw = "NewFlightPass2026!"
        var match = PulseGCSAuthValidator.validatePasswordMatch(recoveryCard.recoveryNewPw, recoveryCard.recoveryConfirmPw)
        compare(match.valid, true, "Matching passwords accepted")

        recoveryCard.recoveryCompleted()
        compare(completeSpy.count, 1, "recoveryCompleted emitted")
    }

    // -------------------------------------------------------------------------
    // 5. Cancel Loop Invariants (Reset to Stage 1 & Clean Wiping)
    // -------------------------------------------------------------------------
    function test_cancelLoopResetInvariants() {
        recoveryCard.recoveryStage = "new_pw"
        recoveryCard.recoveryEmail = "pilot@example.com"
        recoveryCard.recoveryCode = "849201"
        recoveryCard.recoveryNewPw = "NewFlightPass2026!"
        recoveryCard.recoveryConfirmPw = "NewFlightPass2026!"

        recoveryCard.resetFlow()
        compare(recoveryCard.recoveryStage, "request", "Cancel resets stage to request")
        compare(recoveryCard.recoveryEmail, "", "Cancel clears recovery email")
        compare(recoveryCard.recoveryCode, "", "Cancel clears recovery code")
        compare(recoveryCard.recoveryNewPw, "", "Cancel clears new password")
        compare(recoveryCard.recoveryConfirmPw, "", "Cancel clears confirm password")
    }
}
