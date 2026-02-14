# RAMSBuilder (iOS SwiftUI Scaffold)

SwiftUI scaffold for a **Construction RAMS Builder** app, including:

- Login screen (mock auth for now)
- Wizard flow:
  1. Master Document
  2. RAMS + Method Statement + Hazard/Risk assessments
  3. Lift Plan (optional, when lifting is involved)
  4. Review + Save + Public Link + Signatures + PDF export
- Reusable local libraries for:
  - Hazard templates
  - Master documents
  - RAMS documents
  - Lift plans
- Risk scoring with review bands:
  - `<L` Very Low
  - `L` Low
  - `M` Medium
  - `H` High
  - `!` Very High
- Digital signature capture and signature table
- PDF export of RAMS, risk details, lift plan, and signatures
- Public link generator placeholder (local scaffold)

> Supabase is intentionally not wired yet; this scaffold is local-first and ready for later Supabase integration.

---

## Project setup (Mac + Xcode)

This repo uses **XcodeGen** to keep the scaffold simple in source control.

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```
2. Generate the Xcode project:
   ```bash
   cd /path/to/repo
   xcodegen generate
   ```
3. Open:
   ```bash
   open RAMSBuilder.xcodeproj
   ```
4. Run on iOS simulator/device.

---

## Architecture summary

- `App/Models/DomainModels.swift`
  - Master Document, RAMS, Hazard templates, Risk assessments, Lift plans, Signatures.
- `App/Services/AppServices.swift`
  - `MockAuthService`
  - `LibraryStore` (JSON storage in Application Support)
  - `PublicLinkService` (placeholder URL generator)
  - `PDFExportService` (A4 PDF output)
- `App/ViewModels/AppViewModels.swift`
  - Session, library, and wizard orchestration logic.
- `App/Views/*`
  - Login, dashboard tabs, wizard steps, and reusable UI components.

---

## Current behavior and scope

- **Authentication**: mock only (email + password validation).
- **Persistence**: local JSON file for reusable libraries.
- **Map / drawing images**: photos picker for attaching site map and lift drawing.
- **Public links**: generated placeholder URLs.
- **PDF export**: generated into temporary app storage and shareable through iOS share sheet.

---

## Future Supabase integration points

When you are ready, replace or extend:

- `MockAuthService` -> Supabase Auth
- `LibraryStore` -> Supabase database + storage buckets
- `PublicLinkService` -> Supabase Edge Function / signed public access strategy
- Signature and PDF artifacts -> Supabase Storage

The current view model APIs are already structured to support service swapping with minimal UI changes.
