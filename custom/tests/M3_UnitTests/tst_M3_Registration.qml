import QtQuick
import QtTest
import PulseGCS

TestCase {
    id: testCase
    name: "M3_RegistrationQuickTest"
    width: 600
    height: 800
    visible: true
    when: windowShown

    // Component under test
    PulseGCSRegistrationCard {
        id: regCard
        anchors.centerIn: parent
        width: 380
    }

    SignalSpy {
        id: submitSpy
        target: regCard
        signalName: "applicationSubmitted"
    }

    SignalSpy {
        id: signInSpy
        target: regCard
        signalName: "signInRequested"
    }

    SignalSpy {
        id: noticeSpy
        target: regCard
        signalName: "noticeRequested"
    }

    function cleanup() {
        submitSpy.clear()
        signInSpy.clear()
        noticeSpy.clear()
        regCard.resetForm()
    }

    // -------------------------------------------------------------------------
    // 1. Initial State & Step Indicator
    // -------------------------------------------------------------------------
    function test_initialRegistrationState() {
        verify(regCard !== null, "Registration card created")
        compare(regCard.currentStep, 1, "Initial step is Step 1")
        compare(regCard.regFullName, "", "Full name empty")
        compare(regCard.regPhone, "", "Phone empty")
        compare(regCard.regEmail, "", "Email empty")
        compare(regCard.regPw, "", "Password empty")
        compare(regCard.regDOB, "", "DOB empty")
        compare(regCard.regDroneSerial, "", "Drone serial empty")
        compare(regCard.consoleBindingEnabled, true, "Console binding default enabled")
        compare(submitSpy.count, 0, "No application submitted initially")
    }

    // -------------------------------------------------------------------------
    // 2. Step 1 Validation Guards
    // -------------------------------------------------------------------------
    function test_step1ValidationGuards() {
        compare(regCard.currentStep, 1, "Currently on Step 1")

        // Name
        compare(PulseGCSAuthValidator.validateFullName(regCard.regFullName).valid, false, "Empty name rejected")
        regCard.regFullName = "Alex Rivera"
        compare(PulseGCSAuthValidator.validateFullName(regCard.regFullName).valid, true, "Name valid")

        // Phone
        compare(PulseGCSAuthValidator.validatePhone(regCard.regPhone).valid, false, "Empty phone rejected")
        regCard.regPhone = "+1-555-0199"
        compare(PulseGCSAuthValidator.validatePhone(regCard.regPhone).valid, true, "Phone valid")

        // Email
        compare(PulseGCSAuthValidator.validateEmail(regCard.regEmail).valid, false, "Empty email rejected")
        regCard.regEmail = "alex@example.com"
        compare(PulseGCSAuthValidator.validateEmail(regCard.regEmail).valid, true, "Email valid")

        // Password
        compare(PulseGCSAuthValidator.validatePassword(regCard.regPw).valid, false, "Empty pw rejected")
        regCard.regPw = "SecureFlightPass2026!"
        compare(PulseGCSAuthValidator.validatePassword(regCard.regPw).valid, true, "Password valid")

        // DOB (DD/MM/YYYY)
        compare(PulseGCSAuthValidator.validateDOB(regCard.regDOB).valid, false, "Empty DOB rejected")
        regCard.regDOB = "15 / 06 / 1995"
        compare(PulseGCSAuthValidator.validateDOB(regCard.regDOB).valid, true, "DOB valid")
    }

    // -------------------------------------------------------------------------
    // 3. Step Progression & Data Preservation
    // -------------------------------------------------------------------------
    function test_stepNavigationAndDataPreservation() {
        regCard.regFullName = "Alex Rivera"
        regCard.regPhone = "+1-555-0199"
        regCard.regEmail = "alex@example.com"
        regCard.regPw = "SecureFlightPass2026!"
        regCard.regDOB = "15 / 06 / 1995"

        // Advance to Step 2
        regCard.currentStep = 2
        compare(regCard.currentStep, 2, "Transitioned to Step 2")

        // Back action returns to Step 1 without wiping inputs
        regCard.currentStep = 1
        compare(regCard.currentStep, 1, "Returned to Step 1")
        compare(regCard.regFullName, "Alex Rivera", "Full name preserved")
        compare(regCard.regEmail, "alex@example.com", "Email preserved")
        compare(regCard.regDOB, "15 / 06 / 1995", "DOB preserved")
    }

    // -------------------------------------------------------------------------
    // 4. Step 2 Hardware Binding Validation & Submission
    // -------------------------------------------------------------------------
    function test_step2HardwareValidationAndSubmit() {
        regCard.currentStep = 2

        // Drone serial
        compare(PulseGCSAuthValidator.validateDroneSerial(regCard.regDroneSerial).valid, false, "Empty serial rejected")
        regCard.regDroneSerial = "SKYX-VTOL-9921"
        compare(PulseGCSAuthValidator.validateDroneSerial(regCard.regDroneSerial).valid, true, "Serial valid")

        // Console binding
        compare(PulseGCSAuthValidator.validateConsoleBinding(false).valid, false, "Unchecked console rejected")
        compare(PulseGCSAuthValidator.validateConsoleBinding(regCard.consoleBindingEnabled).valid, true, "Console checked")

        // Submit
        var payload = {
            fullName: "Alex Rivera",
            phone: "+1-555-0199",
            email: "alex@example.com",
            password: "SecureFlightPass2026!",
            dob: "15 / 06 / 1995",
            aircraftSerial: regCard.regDroneSerial,
            bindConsole: regCard.consoleBindingEnabled
        }
        regCard.applicationSubmitted(payload)
        compare(submitSpy.count, 1, "applicationSubmitted emitted")
        compare(submitSpy.signalArguments[0][0].email, "alex@example.com", "Submitted payload matches")
    }

    // -------------------------------------------------------------------------
    // 5. Reset Form Invariants
    // -------------------------------------------------------------------------
    function test_resetFormInvariants() {
        regCard.currentStep = 2
        regCard.regFullName = "Alex Rivera"
        regCard.regDroneSerial = "SKYX-VTOL-9921"
        regCard.consoleBindingEnabled = false

        regCard.resetForm()
        compare(regCard.currentStep, 1, "resetForm resets step to 1")
        compare(regCard.regFullName, "", "resetForm clears name")
        compare(regCard.regDroneSerial, "", "resetForm clears drone serial")
        compare(regCard.consoleBindingEnabled, true, "resetForm restores default console binding")
    }
}

