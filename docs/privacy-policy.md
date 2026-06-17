> **DRAFT — review before publishing.** Run this past a privacy-policy
> generator or a lawyer before hosting it live.

# Privacy Policy

**Effective date:** _(to be set on publication)_

---

## Overview

pause is a personal-finance reflection tool that helps you understand the real cost of purchases in terms of your working hours, days, and monthly income. This Privacy Policy explains what information pause stores, where it is kept, and how it is (and is not) used. Because pause is designed to work entirely on your device, it has no backend, no accounts, and no analytics — your financial data stays with you.

pause is open source. You can review the full source code — and verify the data practices described in this policy — at https://github.com/julianchong00/pause-app.

---

## Information we store

pause stores only the data you enter directly. This falls into two categories:

**Your profile:**
- Annual salary or hourly rate (and which type you entered)
- Monthly take-home pay
- FIRE (Financial Independence, Retire Early) savings target
- Preferred currency
- Snooze-days preference (how long to delay a purchase decision)

**Your purchase evaluations:**
- Item label (the name of the purchase you are evaluating)
- Price
- Category
- Date of the evaluation
- Your worth-it decision (yes or no)

You choose what to enter. pause never asks for your name, email address, location, or any other identifying information.

---

## Where your data is stored

All data is stored locally on your device using [Hive](https://pub.dev/packages/hive), an on-device key-value database. Your data is:

- **Never transmitted** to any server operated by pause or anyone else.
- **Never collected** by the developer.
- **Never sold, shared, or disclosed** to third parties.
- **Never backed up** to external cloud storage by the app itself (your device's own OS-level backup behaviour is outside pause's control).

There are no user accounts, no sign-in, and no remote storage of any kind.

---

## Third-party services

pause uses the [`google_fonts`](https://pub.dev/packages/google_fonts) Flutter package to render typography. On first launch (or when a font file is not already cached on your device), this package may fetch font files directly from Google's servers. This request contains only standard HTTP metadata (your IP address and the name of the font file); no pause data — no salary, no purchases, nothing you have entered — is included in or derivable from the request.

Google's handling of these font requests is governed by Google's own Privacy Policy:
[https://policies.google.com/privacy](https://policies.google.com/privacy)

Once a font file is cached on your device, no further network request is made for it.

pause has no other third-party SDKs, analytics libraries, crash reporters, or advertising networks.

---

## Deleting your data

Uninstalling the pause app from your device removes all locally stored data. No copy is retained elsewhere.

An in-app "Reset app data" option (to clear all data and return to the onboarding screen without uninstalling) is planned for a future update.

---

## Children's privacy

pause is not directed at children under the age of 13, and we do not knowingly store information entered by children under 13. If you are a parent or guardian and believe your child has provided information through this app, please contact us (see below) and we will address it promptly.

---

## Changes to this policy

We may update this Privacy Policy from time to time. When we do, the **Effective date** at the top of this document will be updated to reflect the date of the latest revision. We encourage you to review this policy periodically. Continued use of the app after a policy update constitutes acceptance of the revised policy.

---

## Contact

If you have any questions about this Privacy Policy or about how pause handles your data, please reach out via email:

**`feedback@pause.app`**

> Note: `feedback@pause.app` is the current value of `kFeedbackEmail` in the app's source code. This address is a placeholder pending registration of the `pause.app` domain. Once the domain is registered and email forwarding is configured, this will be a live address. Until then, refer to the app's source repository for the most current contact address.
