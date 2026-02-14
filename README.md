# RAMSBuilder (iOS SwiftUI Scaffold)

SwiftUI scaffold for a **Construction RAMS Builder** app, including:

- Login screen (mock auth for now)
- Wizard flow:
  1. Master Document
  2. RAMS + Method Statement + PPE + Hazard/Risk assessments + Emergency protocols
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
- React-style RAMS UX mapping:
  - hazard template quick-add
  - PPE checklist
  - emergency procedure section (first aid, assembly point, emergency contact)

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

## If the app will not build

This repository does **not** commit a `.xcodeproj`; it is generated from `project.yml`.

1. Install XcodeGen (2.38.0+):
   ```bash
   brew install xcodegen
   ```
2. Generate project:
   ```bash
   ./scripts/bootstrap_ios_project.sh
   ```
   (or run `xcodegen generate`)
3. Open `RAMSBuilder.xcodeproj`
4. In Xcode, select scheme `RAMSBuilder` and an iOS 17+ simulator.
5. If needed: **Product > Clean Build Folder**, then build again.

---

## Architecture summary

- `App/Models/DomainModels.swift`
  - Master Document, RAMS, Hazard templates, Risk assessments, Lift plans, Signatures.
- `App/Services/AppServices.swift`
  - `MockAuthService`
  - `LibraryStore` (JSON storage in Application Support)
  - `PublicLinkService` (placeholder URL generator)
  - `PDFExportService` (entry point/wrapper around print engine)
- `App/Services/PDFPrintingEngine.swift`
  - `RamsPDFPrintEngine` (fixed A4 shell, pagination and rendering)
  - `RamsPDFDocumentBuilder` (maps master/RAMS/lift/signatures into printable sections)
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

### PDF printing/pagination design

The print engine uses a deterministic A4 pipeline inspired by DOM-prepagination workflows:

1. **Stable page shell** (`createPageShell`)
   - Fixed `PAGE_WIDTH_PX`, `PAGE_HEIGHT_PX`, and content padding for repeatable measurements.

2. **Root clone preparation** (`prepareRootClone`)
   - Flattens printable sections into blocks.
   - Applies no-split hints to structural blocks (headings/tables/groups) unless splitting is required.
   - Honors explicit section-level forced breaks (equivalent to `rams-force-page-break` boundaries).

3. **Progressive block pagination** (`paginateRoot`)
   - Appends blocks until overflow.
   - On overflow, attempts splitting in ordered strategies:
     - table rows
     - descendant child groups
     - text lines / words
     - immediate children
   - If no safe split is possible, falls back to a last-resort overflow page.

4. **Smart image slicing**
   - Large image blocks (map/drawings/signatures) can be split.
   - The splitter chooses a break row near the ideal slice location by scanning for low-ink (mostly white) horizontal lines to avoid cutting through content.
   - Visually empty slices are discarded.

5. **Structured section export**
   - Contents, Master Document, RAMS Method, Required PPE, Risk Register, Emergency Procedures, optional Lift Plan, Appendices, and Sign-off are rendered as sectioned blocks for predictable page starts and cleaner print output.

6. **Print-style polish layer**
   - Branded cover page with project/reference metadata.
   - Repeating page header/footer with page numbers and issue timestamp.
   - Section banner styling, weighted table columns, zebra rows, and boxed key-value cards.
   - Dedicated digital signature cards for cleaner sign-off pages.

### Brand matching customization

Brand profile values are centralized in:

- `App/Services/PDFBrandTheme.swift`
- `App/Views/Components.swift` color palette (`proSlate*`, `proYellow`) for UI styling

You can customize:

- company name and tagline
- legal footer text
- document status label (e.g. `LIVE / APPROVED`)
- core brand colors (primary/secondary/section/grid)
- logo image by adding an asset named `RAMSLogo` in Xcode (optional fallback monogram is automatic)

`RamsPDFDocumentBuilder` injects this theme into every export so all pages share the same brand system.

---

## Future Supabase integration points

When you are ready, replace or extend:

- `MockAuthService` -> Supabase Auth
- `LibraryStore` -> Supabase database + storage buckets
- `PublicLinkService` -> Supabase Edge Function / signed public access strategy
- Signature and PDF artifacts -> Supabase Storage

The current view model APIs are already structured to support service swapping with minimal UI changes.
