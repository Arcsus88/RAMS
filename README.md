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
- `App/Models/DocumentAndRAMSSchema.swift`
  - Contract-style schema models for Master Document, Master Cover Config, Master Template, RAMS, and Hazard.
  - Includes explicit field constraint validation (required fields, min/max lengths, array limits, URL checks, and bounded integers).
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

## Document and RAMS schema contract

The repository now includes a dedicated schema layer in:

- `App/Models/DocumentAndRAMSSchema.swift`

This is intentionally separate from the UI-oriented domain models used by the wizard so that API contract validation can evolve without breaking scaffolding UX.

Implemented schema coverage:

- `MasterDocument`
  - Create payload: `projectId` required.
  - Create/update optional fields validated: `title` (1...200), `documentReference` (1...120).
  - Update status enum: `Draft | Issued | Closed | Archived`.
- `MasterCoverConfig`
  - Full field set from the contract including appendix metadata, user/recipient arrays, communication methods, PPE/permit/emergency fields, and long-form notes.
  - Enforces declared max lengths, list sizes, and appendix URL/size constraints.
- `MasterTemplate`
  - Create payload requires `title` and `coverConfig`, supports partial cover config object.
  - Section model validates `sectionTitle`, optional `sectionReference`, optional `displayOrder >= 0`, optional notes, and optional lifting plan object payload.
  - Update status enum: `Active | Archived`.
- `RAMS`
  - Required project details object and required arrays for PPE/equipment/tools/materials/hazards.
  - Method statement field limits, optional category, and optional tags (`max 25`, each `max 50`).
- `Hazard`
  - Required activity/hazard/persons-at-risk/controls fields.
  - Likelihood and severity bounds enforced as `1...5`.

Validation can be called directly with `try payload.validate()` on each schema payload/entity type.

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
