---
name: firebase
description: Firebase patterns and safety rules. Use when working with Firebase, Firestore, Firebase Auth, Firebase deploy, or any firebase CLI commands.
---

## Project

- Project ID: `robbchar-3db11`

## Multi-App Safety

This project contains multiple applications. Before any deploy or config change:
- Confirm which app you are working on
- Scope all changes to that app only
- Never overwrite config, rules, functions, or data belonging to other apps in the same project.
- All deployments should be isolated to the app you are working on. If you need to deploy changes to multiple apps, do them one at a time.

## What stays centralized in the firebase-robbchar-config repo

- Firebase project-level config (firebase.json targets, project aliases) 
- firebase rules for all apps (firestore.rules, storage.rules, etc)

## What stays in the app repos

- Cloud Functions (they're just code, they live with the code that calls them)
- Hosting config and rewrites (tightly coupled to the app's routing, they must be the same as thecentralized rules but only for the specific app)
- App-specific firebase.json deploy targets

## Firestore Rules Pattern

Always write rules scoped to the app's namespace:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }

    match /APP-NAMESPACE {
      WRITE_RULES_ONLY_HERE
    }
  }
}
```

Never modify rules outside the current app's namespace block. In addition all firestore rules are only kept within the ~/Projects/firebase-robbchar-config project which should be updated with anything new and then deployment happens from that project.

## Testing
It is imperitave and required that all testing of anything that uses firebase much have mocks so that firebase is not hit directly during testing.