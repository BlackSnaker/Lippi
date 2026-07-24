# App Review notes

Lippi is a productivity and general-wellbeing app. It is not a medical device and does not diagnose, treat, or make clinical decisions.

## Access

No external account or review credentials are required.

On the authentication screen, choose Sign Up and enter:

- any syntactically valid email address;
- any display name;
- a password of at least eight characters.

The account is created only inside the app container. No email is sent and no server account is created.

## Optional permissions

- Apple Health and Apple Watch context is optional. The rest of the app works when HealthKit access is declined or when no samples are available.
- Microphone and Speech permissions are requested only when the reviewer starts the voice assistant.
- Notifications are optional.

## On-device models

Lippi starts downloading the pinned Bonsai 4B model on first launch. The file is approximately 572 MB and is verified before installation. Smart Goals become fully available after this one-time download.

The optional neural voice model is approximately 129 MB and can be installed from Settings. Its state shows download, verification, installation, readiness, and recoverable errors.

Both models run locally. Goal text, generated roadmaps, HealthKit information, and synthesized speech are not sent to an external AI provider.

## Suggested review path

1. Create the local account.
2. Open Today and add a task.
3. Start and stop a short focus session.
4. Open Smart Goals. If the Bonsai download is still in progress, review its live status or continue testing another section until verification completes.
5. Create a goal with a concrete outcome and constraints, then generate the roadmap.
6. Open Settings to review model controls and the in-app Privacy Policy link.

The app includes two WidgetKit extensions and Live Activities. It does not include in-app purchases, subscriptions, ads, or external account sign-in.
