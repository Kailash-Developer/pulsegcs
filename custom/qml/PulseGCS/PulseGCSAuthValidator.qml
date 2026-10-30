pragma Singleton
import QtQuick

QtObject {
    id: validator

    // Email validation: validates presence and RFC 5322 standard pattern
    function validateEmail(email) {
        if (!email || email.trim().length === 0) {
            return { valid: false, error: qsTr("Email address is required.") }
        }
        var trimmed = email.trim()
        var regex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/
        if (!regex.test(trimmed)) {
            return { valid: false, error: qsTr("Please enter a valid email address.") }
        }
        return { valid: true, error: "" }
    }

    // Password validation: requires minimum 8 characters
    function validatePassword(password) {
        if (!password || password.length === 0) {
            return { valid: false, error: qsTr("Password is required.") }
        }
        if (password.length < 8) {
            return { valid: false, error: qsTr("Password must be at least 8 characters.") }
        }
        return { valid: true, error: "" }
    }

    // Password confirmation matching validation
    function validatePasswordMatch(pw1, pw2) {
        if (!pw1 || pw1.length < 8) {
            return { valid: false, error: qsTr("New password must be at least 8 characters.") }
        }
        if (!pw2 || pw2.length === 0) {
            return { valid: false, error: qsTr("Please confirm your new password.") }
        }
        if (pw1 !== pw2) {
            return { valid: false, error: qsTr("Passwords do not match. Please re-enter.") }
        }
        return { valid: true, error: "" }
    }

    // 6-digit recovery code validation
    function validateRecoveryCode(code, authoritativeCode) {
        if (!code || code.trim().length === 0) {
            return { valid: false, error: qsTr("Please enter the 6-digit verification code.") }
        }
        var trimmed = code.trim()
        if (!/^\d{6}$/.test(trimmed)) {
            return { valid: false, error: qsTr("Verification code must be exactly 6 digits.") }
        }
        // If an explicit authoritative code is passed (e.g. unit tests), verify match;
        // otherwise permit format to pass to backend service for attempt-counting and rate-limiting
        if (authoritativeCode && trimmed !== authoritativeCode) {
            return { valid: false, error: qsTr("Invalid verification code. Please check and try again.") }
        }
        return { valid: true, error: "" }
    }

    // Full name validation: requires at least 2 characters and only letters and spaces (no numbers or special symbols)
    function validateFullName(name) {
        if (!name || name.trim().length === 0) {
            return { valid: false, error: qsTr("Full name is required.") }
        }
        var trimmed = name.trim()
        if (trimmed.length < 2) {
            return { valid: false, error: qsTr("Please enter your full legal name.") }
        }
        var nameRegex = /^[a-zA-Z\s\.\'\-]+$/
        if (!nameRegex.test(trimmed)) {
            return { valid: false, error: qsTr("Full name should only contain letters, spaces, dots, or hyphens.") }
        }
        return { valid: true, error: "" }
    }

    // Phone number validation: targeting Indian customers (exact 10 digits, starts with 6-9, no characters)
    function validatePhone(phone) {
        if (!phone || phone.trim().length === 0) {
            return { valid: false, error: qsTr("Phone number is required.") }
        }
        var trimmed = phone.trim()
        if (!/^\d+$/.test(trimmed)) {
            return { valid: false, error: qsTr("Phone number must contain digits only (no characters).") }
        }
        if (trimmed.length !== 10) {
            return { valid: false, error: qsTr("Phone number must be exactly 10 digits.") }
        }
        if (!/^[6-9]\d{9}$/.test(trimmed)) {
            return { valid: false, error: qsTr("Please enter a valid 10-digit Indian mobile number (starts with 6-9).") }
        }
        return { valid: true, error: "" }
    }

    // Date of birth calendar validation: checks DD (01-31), month (01-12), and valid calendar days in month
    function validateDOB(dob) {
        if (!dob || dob.trim().length === 0) {
            return { valid: false, error: qsTr("Date of birth is required.") }
        }
        var trimmed = dob.trim()
        var dmyMatch = trimmed.match(/^(\d{1,2})[\s\/\-\.]+(\d{1,2})[\s\/\-\.]+(\d{4})$/)
        var isoMatch = trimmed.match(/^(\d{4})[\s\/\-\.]+(\d{1,2})[\s\/\-\.]+(\d{1,2})$/)

        if (!dmyMatch && !isoMatch) {
            return { valid: false, error: qsTr("Please enter date of birth in DD / MM / YYYY format.") }
        }

        var day = dmyMatch ? parseInt(dmyMatch[1], 10) : parseInt(isoMatch[3], 10)
        var month = dmyMatch ? parseInt(dmyMatch[2], 10) : parseInt(isoMatch[2], 10)
        var year = dmyMatch ? parseInt(dmyMatch[3], 10) : parseInt(isoMatch[1], 10)

        if (month < 1 || month > 12) {
            return { valid: false, error: qsTr("Invalid month. Month must be between 01 and 12.") }
        }
        if (day < 1 || day > 31) {
            return { valid: false, error: qsTr("Invalid day. Day must be between 01 and 31.") }
        }

        // Calendar day-in-month check (handles leap years 28/29, 30-day months, 31-day months)
        var daysInTargetMonth = new Date(year, month, 0).getDate()
        if (day > daysInTargetMonth) {
            return { valid: false, error: qsTr("Invalid calendar date for the selected month.") }
        }

        var currentYear = new Date().getFullYear()
        if (year < 1920 || year > currentYear) {
            return { valid: false, error: qsTr("Please enter a valid birth year.") }
        }

        var today = new Date()
        var birthDate = new Date(year, month - 1, day)
        if (birthDate > today) {
            return { valid: false, error: qsTr("Date of birth cannot be in the future.") }
        }

        var age = today.getFullYear() - year
        var mDiff = today.getMonth() - (month - 1)
        if (mDiff < 0 || (mDiff === 0 && today.getDate() < day)) {
            age--
        }
        if (age < 18) {
            return { valid: false, error: qsTr("Remote flight operator must be at least 18 years of age.") }
        }

        return { valid: true, error: "" }
    }

    // Drone serial number validation: length must be strictly more than 10 characters with hyphens in between alphanumeric segments
    function validateDroneSerial(serial) {
        if (!serial || serial.trim().length === 0) {
            return { valid: false, error: qsTr("Drone serial number is required.") }
        }
        var trimmed = serial.trim()
        if (trimmed.length <= 10) {
            return { valid: false, error: qsTr("Drone serial number must be more than 10 characters.") }
        }
        var serialRegex = /^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)+$/
        if (!serialRegex.test(trimmed)) {
            return { valid: false, error: qsTr("Drone serial number must contain alphanumeric segments separated by hyphens (e.g. SKYX-KSN-2026-0842).") }
        }
        return { valid: true, error: "" }
    }

    // Device binding validation
    function validateConsoleBinding(bound) {
        if (!bound) {
            return { valid: false, error: qsTr("Device binding is required for license attestation.") }
        }
        return { valid: true, error: "" }
    }

    function validateDeviceBinding(bound) {
        return validateConsoleBinding(bound)
    }
}

