Bonaparte is a Rails application that turns an auto parts store's source Excel
file into an enriched catalog. It researches equivalent part numbers, saves
vehicle fitments, interchanges, and specifications, and publishes the results
on screen and in a six-sheet Excel workbook.

Read these before changing domain behavior:

- `docs/alcance.md`: scope, domain vocabulary, workbook layout, and research rules.
- `docs/busqueda-de-similes.md`: candidate selection, source acceptance, reuse, and persistence.
- The relevant models, specs, `db/schema.rb`, and configuration: the implemented behavior.

Some docs describe earlier plans: they mention `CatalogResearch`, missing
`source_rows`, and user ownership of stores. The current implementation uses
`Datasheet::Research`, has source rows, and has no User–PartStore association.
Do not implement an old pending item or assume ownership checks exist without
checking the code. Resolve behavior changes against the user's request and specs.

This is an auto parts catalog application. Infrastructure/PaaS descriptions in
an ancestor directory's instructions do not describe this repository.

## Runtime and architecture

- Ruby **4.0.0**, pinned in `.ruby-version`; Rails **8.1**, pinned by Gemfile/lockfile.
- PostgreSQL and Active Record for domain data and constraints.
- Devise for authentication; Simple Form for forms.
- Turbo, Stimulus, Tailwind CSS 4, import maps, and Propshaft for the interface.
- Roo for input spreadsheets, caxlsx for export, and pdf-reader for PDF sources.
- SerpApi through Net::HTTP for search; RubyLLM for fallback transcription.
- Active Storage for temporary upload attachments; Active Job for research.
- Production uses Solid Queue with its queue database; Solid Cache and Solid Cable
  are also configured. Check environment configuration before assuming an adapter.

### Processing flow

1. A signed-in user opens a store and uploads an Excel file. The dashboard lists stores.
2. `DatasheetsController` creates an upload datasheet, attaches the file, and enqueues
   `DatasheetResearchJob`.
3. The job calls `Datasheet::Research`, which saves the Origen rows and reuses saved
   parts or equivalent datasheets within that store before searching externally.
4. For missing candidates, research selects an acceptable source, extracts details,
   and saves the equivalent datasheet and the store's part together.
5. `Datasheet::CatalogView` joins saved input rows, parts, and research for the screen.
   `Datasheet::Workbook` uses that same view to generate the download.
6. The job purges the upload attachment after successful processing. On exceptions,
   it marks the upload failed and re-raises; do not assume every attachment is purged.

Controllers handle HTTP, authentication, permitted input, and rendering. Jobs
schedule and invoke domain behavior. Models own business decisions. Views and
Stimulus controllers handle presentation and focused browser interactions.

## Model and class map

Paths below are relative to `app/models/`. Namespaced classes are domain helpers;
they do not all inherit from Active Record or represent tables.

### Persisted models

| File / class                                  | Responsibility                                                                                                                                   |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `application_record.rb` — `ApplicationRecord` | Abstract Active Record base for persisted models.                                                                                                |
| `user.rb` — `User`                            | Person's name, email, and Devise authentication, registration, recovery, and remembered sessions.                                                |
| `part_store.rb` — `PartStore`                 | Store whose commercial name labels the catalog; groups uploads and equivalent research.                                                          |
| `datasheet.rb` — `Datasheet`                  | Represents either an upload holding source rows or an equivalent part's research holding shared details and status.                              |
| `source_row.rb` — `SourceRow`                 | Original Origen row and position. Its normalized part number plus description form the lookup fingerprint.                                       |
| `part.rb` — `Part`                            | Store's commercial reference, phrase, labels, description, and fingerprint, linked to the researched equivalent's datasheet.                     |
| `application.rb` — `Application`              | Vehicle fitment with manufacturer, model, year range, engine, and market. This means part compatibility, not a software application.             |
| `interchange.rb` — `Interchange`              | Alternative part number, brand, and OEM/Aftermarket origin belonging to a researched datasheet.                                                  |
| `attribute.rb` — `Attribute`                  | Part specification with class, name, unit, and value. Accessed from Datasheet as `part_attributes` to avoid the Active Record `attributes` name. |

### Catalog workflow

| File / class                                           | Responsibility                                                                                          |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `datasheet/research.rb` — `Datasheet::Research`        | Imports source rows, batches reuse checks, searches missing equivalents, and records processing status. |
| `datasheet/catalog_view.rb` — `Datasheet::CatalogView` | Builds all six catalog sections from saved records, expands fitment years, and computes metrics.        |
| `datasheet/workbook.rb` — `Datasheet::Workbook`        | Writes the catalog view to XLSX with the required sheet order, headers, and filename.                   |

### Research helpers

All files in this table are under `app/models/datasheet/research/` and use the
`Datasheet::Research::` namespace.

| File / class                                  | Responsibility                                                                                                                                                                                     |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `spreadsheet_reader.rb` — `SpreadsheetReader` | Opens the input workbook through Roo; Research selects and persists Origen rows.                                                                                                                   |
| `phrase.rb` — `Phrase`                        | Parses candidates, vehicle/year/engine hints, group aliases, and oversize values locally; compares part number spellings.                                                                          |
| `stored_row.rb` — `StoredRow`                 | Skips an existing part fingerprint or attaches a new reference to saved equivalent research. Nested `Lookup` caches batch data and stages bulk inserts.                                            |
| `page_search.rb` — `PageSearch`               | Tries candidates and queries in order, checks source identity and fitments, retries unavailable requests, and selects a page or overview fallback.                                                 |
| `serp_api_search.rb` — `SerpApiSearch`        | Calls Google search and overview engines through SerpApi. Nested `Reply` carries links, snippets, overview data, and citations. `OutOfCredits` signals exhaustion separately from request failure. |
| `serp_api_account.rb` — `SerpApiAccount`      | Fetches and caches the available search balance and tracks consumption during a run.                                                                                                               |
| `page_fetch.rb` — `PageFetch`                 | Downloads HTML/PDF sources with timeouts and bounded redirects; extracts identity metadata used to check a hit.                                                                                    |
| `page_tables.rb` — `PageTables`               | Reads supplier tables, schema.org Product data, compatibility descriptions, and Fits clauses into common row objects.                                                                              |
| `catalog_rows.rb` — `CatalogRows`             | Extracts fitments from catalog text/PDF rows led by the candidate number; also prepares relevant excerpts for transcription.                                                                       |
| `page_lists.rb` — `PageLists`                 | Coordinates extraction fallbacks, validates evidence, removes unusable rows, and completes accepted details with unambiguous phrase hints.                                                         |
| `page_rewrite.rb` — `PageRewrite`             | Uses RubyLLM to transcribe supplied source text into structured details when regular readers cannot extract fitments.                                                                              |
| `page_schema.rb` — `PageSchema`               | Defines the structured AI response shape; acceptance of its content remains PageLists' responsibility.                                                                                             |
| `simile_record.rb` — `SimileRecord`           | Persists the research outcome, related lists, and store part transactionally, reusing completed research where available.                                                                          |
| `unavailable.rb` — `Unavailable`              | Common error for unavailable search, download, or transcription operations; distinct from an answered search with no match.                                                                        |

## Domain rules to preserve

- Research reuse is scoped to a store. Equivalent datasheets are identified by
  store plus `equivalent`; parts by store plus fingerprint. Keep database uniqueness
  and concurrency protections in place.
- Several parts may share one equivalent datasheet and its lists. Keep the store's
  reference/brand/product separate from the researched source's identity.
- Preserve duplicate Origen rows and their positions. Deduplicating parts must not
  remove or reorder the original input lines.
- A candidate mentioned only as another product's interchange is insufficient
  evidence that a page describes that candidate.
- Select a usable source according to the documented rules; do not combine unrelated
  pages or use an overview to fill gaps under a different page's URL.
- Require supported vehicle fitments before publishing related details. Input hints
  and AI output alone must not manufacture evidence or unknown values.
- Preserve distinct pending, created, not_found, and failed states. A completed
  missing/failed equivalent is reused under current rules; do not silently add retries.
- Publication reads stored data. It must not perform searches, invoke AI, or reopen
  the original upload. Repeated publication of saved data must keep the same content/order.
- Excel sheets are Origen, Métricas, Aplicaciones, Intercambios, Atributos, Catálogo.
  Preserve their Spanish headers, source order, catalog sorting, and yearly expansion.

## Development: mandatory BDD/TDD workflow

Follow this sequence for every new feature and behavioral bug fix. Work in small
vertical slices. Do not write production behavior first and add tests afterward.

1. **Understand and locate.** Read the relevant docs, implementation, specs, and
   schema. Identify the user outcome, owning model, boundaries, persistence needs,
   and effects on determinism, concurrency, failure handling, and external calls.
   Ask only about ambiguities that materially change the behavior; otherwise proceed
   with an explicit, reasonable assumption.
2. **Specify behavior (BDD).** State the acceptance scenarios in Given/When/Then form
   before implementation. Cover the successful path, relevant invalid input/failure,
   and reuse or retry cases when applicable. Map each scenario to an observable
   outcome and a spec. Use RSpec descriptions/contexts; do not add Cucumber or a new
   test framework just to express BDD.
3. **Plan a slice.** Name the model behavior and the narrowest useful test layer.
   Use model specs for domain rules, request specs for HTTP/Turbo, and job specs for
   enqueueing and execution boundaries. Use browser/system verification when the
   interaction cannot be established by request specs alone.
   Apply the complexity checks below and draft the public contract comments before
   implementing the behavior. Keep the comments aligned with the acceptance scenarios.
4. **Red.** Write the smallest meaningful failing example, then run it. Confirm that
   it fails because the requested behavior is missing or broken. A boot, connection,
   syntax, missing dependency, or fixture error is not a valid red result; resolve
   the setup issue before proceeding. For regressions, reproduce the reported trigger.
5. **Green.** Implement only enough behavior in the owning model to pass that example.
   Connect the controller/job/view as needed for the slice. Preserve existing public
   contracts and avoid speculative abstractions or unrelated cleanup.
6. **Refactor.** With the example green, improve names, duplication, query usage, and
   responsibility boundaries without changing behavior. Run the example again after
   refactoring. Repeat red–green–refactor for the remaining acceptance scenarios.
7. **Integrate and verify.** Run affected specs together, then the full RSpec suite
   for feature changes. Run RuboCop and any relevant autoload, migration, security,
   or browser checks. Resolve regressions; distinguish pre-existing failures from
   new ones with evidence. Do not weaken tests merely to obtain a green result.
8. **Report completion.** State the behavior delivered, scenarios covered, observed
   red/green results, commands run, and any remaining verification limits. Update
   affected documentation. Do not claim success for checks that could not run.

Example acceptance scenario:

```gherkin
Given a store already has research for an equivalent part
And a new source row has a different fingerprint but the same candidate
When the upload is processed
Then the new part links to the stored equivalent datasheet
And no new external search is made for that row
```

For documentation-only or presentation-only changes without behavioral effects,
review accuracy and formatting with proportionate checks; do not invent behavior
tests or claim a red/green cycle that did not occur.

### Model-first implementation policy

- Put business rules, state transitions, persistence decisions, and domain queries
  in the model class that owns them. Prefer explicit, intention-revealing model
  methods over moving decisions into controllers, jobs, or views.
- Do not introduce service objects, an `app/services` layer, or new standalone POROs
  as the default solution to business behavior. Do not add a class with a single
  generic `call` method merely to move model logic elsewhere.
- Existing `Datasheet::*` workflow/readers are plain Ruby classes in the model
  namespace. Preserve and maintain them as established architecture; their existence
  is not a reason to extract every new rule into another object. Do not force them
  to inherit from ApplicationRecord or rewrite them as part of unrelated work.
- Prefer cohesive model methods first. If a new boundary is truly needed, explain
  the concrete responsibility and tradeoff before expanding the architecture.
- Keep controllers focused on HTTP and jobs on asynchronous execution. Prefer
  explicit workflow methods over callbacks that hide network calls or complex work.

### Managing complexity when designing a feature

Judge complexity by the effort needed to understand and safely change behavior,
not by file length or class count. Watch for these three symptoms:

| Symptom              | What it means                                                                         | Project review question                                                                                                                                   |
| -------------------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Change amplification | One conceptual change requires edits in many places.                                  | Would adding a catalog field require independently rewriting its meaning in the model, view, and export? Keep the definition with its owner and reuse it. |
| Cognitive load       | A developer must hold too many details in mind to do a task correctly.                | Must a caller understand candidate parsing, retries, and persistence to process an upload? Let the owning workflow handle those details.                  |
| Unknown unknowns     | A required fact or dependency is hidden, so a developer does not know to look for it. | Could changing bulk inserts silently skip a callback or break store-scoped deduplication? Make that dependency discoverable at the affected boundary.     |

Dependencies and unclear behavior accumulate complexity over time. During design
and refactoring, ask what callers must know, what other code must change, and what
important assumptions remain hidden. Address the concrete risk within the feature's
scope; do not use this review to justify unrelated restructuring.

#### Small interfaces with rich implementations

Prefer a clear domain operation that hides substantial work behind a simple,
complete contract. Interface complexity includes required knowledge, options,
side effects, and call order, not just the number of public methods.

- Keep parsing rules, reuse decisions, and persistence details with their owner.
  Avoid making controllers or jobs coordinate private workflow steps.
- For example, callers of `Datasheet::CatalogView` should request catalog sections
  without duplicating fingerprint matching or year expansion.
- Do not split behavior into tiny classes, forwarding methods, or configuration
  flags unless the new boundary hides knowledge and simplifies actual callers.
- A short signature is insufficient if it hides important side effects or ordering
  requirements. State those obligations in the contract and test them.
- Prefer cohesive model behavior over a growing model with unrelated responsibilities.
  Rich functionality does not excuse tangled internals or a generic service layer.

## Documenting business models, classes, and modules

Every business model, class, and module must have an English comment immediately
above its declaration, including nested types with their own domain responsibility.
Describe the abstraction a reader can rely on without tracing the implementation.
Use a short paragraph; add detail only when it prevents a concrete misunderstanding.

### Interface comments: what callers need to know

Explain the domain purpose, the data or behavior owned, and how it contributes to
the workflow. Include important guarantees, boundaries, and side effects; do not
turn a class header into a list of methods or a walkthrough of its algorithm.

Document business methods with contracts covering the relevant input meaning,
return values, state changes, failure outcomes, and usage requirements. Clarify
units, ordering, inclusive ranges, nil/empty values, and retry/idempotency behavior
where these matter. Skip repetitive comments on obvious accessors or framework
declarations when they add no information.

For example, this class comment explains the publication boundary:

```ruby
# Builds catalog sections from an upload's saved source rows and store research.
# Includes catalog details only for parts linked to created research datasheets.
# Preserves source order and expands closed fitment ranges into individual years.
# Reads saved records without searching externally or reopening the input file.
class Datasheet::CatalogView
```

### Implementation comments: decisions and hidden dependencies

Place explanations beside the smallest relevant block. Describe why a decision
is necessary, the invariant protected, or a surprising dependency. For example,
explain why concurrent bulk inserts use the same fingerprint order rather than
merely saying that the rows are sorted. Keep internal mechanics out of caller
documentation unless callers must account for them.

Document a shared rule at its owning location and reference it from dependent code
when necessary. Do not copy the same explanation across models, jobs, and controllers.

### Write and maintain comments as part of development

- Draft class and method contracts while planning the BDD/TDD slice, before method
  bodies. If the contract needs unrelated concepts or extensive instructions,
  reconsider the interface before implementing it.
- Add information that names and code do not express. Avoid translating each line
  into English, narrating Rails macros, or using vague claims such as “handles data.”
- Check every guarantee against the code and acceptance specs. Clearly distinguish
  current behavior from a proposal; never document a planned association as implemented.
- Update nearby comments in the same change as behavior. Remove misleading claims
  and use references for longer domain explanations already maintained in `docs/`.
- Review from a caller's perspective: can someone use the operation correctly and
  find its important constraints without reading all its helpers? If not, improve
  the contract or the design rather than adding a longer implementation narrative.

## Ruby 3 / Ruby 4 and Rails 8 conventions

- Treat `.ruby-version`, Gemfile.lock, `.rubocop.yml`, and existing code as the
  executable conventions. Use `rubocop-rails-omakase`; do not substitute a personal
  formatter or broadly reformat untouched files.
- Follow modern Ruby 3/4 conventions: two-space indentation, descriptive snake_case
  methods, CamelCase constants/classes, clear keyword arguments for named inputs,
  explicit `**kwargs` forwarding, guard clauses, and small cohesive methods.
- Prefer readable expressions and standard Enumerable/Active Record APIs. Keep
  visibility explicit, avoid mutable shared state and unnecessary metaprogramming,
  and rescue specific errors at the layer that can handle them meaningfully.
- The current app runs on Ruby 4.0; Rails 8.1 requires at least Ruby 3.2 and individual
  dependencies may require newer Ruby 3 versions. Do not interpret README's “Ruby 3+”
  as tested support for every Ruby 3 release. Verify the complete dependency set and
  run tests on the intended version before claiming compatibility.
- Avoid Ruby 4-only syntax or experimental runtime features when a clear Ruby 3
  equivalent serves the same purpose. Check upgrade notes and explicit default/bundled
  gem dependencies rather than assuming older standard-library availability.
- Follow Rails MVC, RESTful actions, Zeitwerk naming, associations, validations, scopes,
  and strong parameters. Use the APIs available in the locked Rails 8.1 version.
- Enforce persistence invariants with database constraints/indexes where necessary;
  model validation alone cannot protect concurrent writes. Use reversible migrations
  and regenerate schema through Rails instead of hand-editing it.
- Use transactions for related database changes and deliberate locks/upserts for
  concurrency. Avoid holding transactions open across network requests.
- Bulk inserts/deletes bypass callbacks and validations: account explicitly for
  required attributes, timestamps, constraints, and dependent cleanup.
- Avoid N+1 queries and loading entire catalogs unnecessarily; use preloading,
  targeted queries, and batching appropriate to the data size.
- Keep Active Job work safe to retry. Preserve the reuse/deduplication rules and
  exercise failure and partial-progress behavior with specs.
- Respect Turbo frame boundaries. A frame expects matching content; full-page
  success navigation and inline validation errors need intentional response handling.
  Cover redirect destinations, flash messages, statuses, and response formats.
- Write code comments in English. Explain domain purpose and important decisions;
  keep required workbook labels and headers in their specified language.

## Testing and commands

Use the project's Ruby, not OS system Ruby. On an rbenv machine, prefix commands
with `rbenv exec` if the shell has not selected the project runtime.

```sh
ruby -v
bundle install
bin/rails db:prepare
bin/dev
```

`bin/dev` currently starts the web server and Tailwind watcher. It does not start
a Solid Queue worker. When testing a queue-backed environment, run `bin/jobs`
separately with the appropriate database/environment configuration.

```sh
# Red/green: target the example or file for the current slice.
bundle exec rspec spec/models/datasheet/research_spec.rb:5
bundle exec rspec spec/models/datasheet/research_spec.rb

# Integration and final feature verification.
bundle exec rspec
bin/rubocop
bin/rails zeitwerk:check
git diff --check
```

RSpec uses FactoryBot, Shoulda Matchers, transactional fixtures, and Devise request
helpers. Stub/inject SerpApi, downloads, account lookups, and AI responses at their
boundaries. Specs must not use live services, spend credits, or require real API keys.
Test meaningful outcomes, including ordering, reuse, failures, and export contents;
avoid tests that only repeat implementation details.

For security/dependency changes, use the configured checks where relevant:

```sh
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

Inspect `config/ci.rb` and `.github/workflows/ci.yml` before relying on `bin/ci` or
GitHub checks. They currently configure setup, lint, and security checks without
running RSpec; a green CI badge does not establish that the feature specs passed.

## Configuration and change boundaries

- Keep `.env`, `config/master.key`, backups, and plaintext credentials out of Git
  and logs. Use the existing `SERPAPI_API_KEY` and `OPENAI_API_KEY` configuration.
- Rails decrypts `config/credentials.yml.enc` with `RAILS_MASTER_KEY` or the local
  `config/master.key`. `secret_key_base` is a separate credential. Diagnose a mismatch
  without printing keys; never reset or rotate credentials just to get tests to boot
  unless the user explicitly requests the reset.
- The `.env` initializer is a simple local loader, not full dotenv syntax, and it
  preserves already-set environment variables. It runs during initialization; do
  not assume it can supply every setting needed earlier in the boot process.
- Preserve authentication and do not invent store ownership guarantees absent from
  the schema. Treat authorization changes as explicit behavior requiring acceptance specs.
- Keep changes focused. Do not add dependencies, change runtimes, alter deployment,
  or refactor unrelated code just to implement a feature.
- Preserve the user's uncommitted work. Do not commit, push, deploy, reset databases,
  or change persistent shell configuration unless the task authorizes it.

## Official references

Use version-matched primary documentation when a language/framework detail is unclear:

- [Rails Guides (select the project's Rails version)](https://guides.rubyonrails.org/)
- [Rails 8.1 release notes](https://guides.rubyonrails.org/8_1_release_notes.html)
- [Active Record Basics](https://guides.rubyonrails.org/active_record_basics.html)
- [Ruby documentation by version](https://www.ruby-lang.org/en/documentation/)
- [Ruby 4.0 release notes](https://www.ruby-lang.org/en/news/2025/12/25/ruby-4-0-0-released/)

Project decisions such as model-first design and the required BDD/TDD sequence are
repository policy, not claims that Rails mandates a single architecture or workflow.
