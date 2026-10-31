# SnapLease - Coding Rules

## 1. Project Overview

Project: SnapLease  
Topic: Ứng dụng quản lý và đặt thuê máy ảnh trực tuyến

Main technology:
- Flutter
- Android first
- flutter_bloc
- GoRouter

Main UI language:
- Vietnamese

Design system:
- Primary color: #1D39C4
- Font: Roboto
- Reference mobile width: 390px
- Default horizontal margin: 12px

---

## 2. Mandatory Architecture Rules

Use:
- Feature-based structure
- Bloc/Cubit for state management
- GoRouter for navigation
- Repository abstraction
- Clear separation between presentation, business logic, and data

Do not use:
- GetX
- Provider as the main state management solution
- Navigator.push / Navigator.pop as the main routing mechanism
- Business logic directly inside widgets
- API calls directly inside UI
- Database connections directly from Flutter

Preferred flow:

UI
→ Bloc/Cubit
→ Repository
→ Data Source

For API-based features:

UI
→ Bloc/Cubit
→ Repository abstraction
→ Repository implementation
→ Remote Data Source
→ Dio
→ Backend API
→ Database

---

## 3. Mock Data Rules

When backend is not available:
- Use mock data
- Keep mock data outside UI
- Do not hard-code mock accounts inside screens
- Mock implementation must follow repository abstractions
- Design the code so mock data can later be replaced by API data with minimal changes

Example:

AuthRepository
→ MockAuthRepository

Later:

AuthRepository
→ AuthRepositoryImpl
→ RemoteAuthDataSource

UI and Bloc should not need major changes when replacing mock data with real API data.

---

## 4. Dio / API Rules

Do not implement Dio until backend/API specifications are available.

Do not:
- invent API URLs
- invent endpoints
- invent request/response structures
- invent authentication mechanisms

When API specifications are available:
- use Dio
- keep Dio inside the data layer
- do not call Dio directly from widgets or Bloc
- create request/response models where appropriate
- map DTO/models to domain entities when necessary

---

## 5. Figma Rules

Figma is the main source of truth for UI.

Always follow the provided Figma frame closely.

Do not invent UI elements that are missing or unclear in Figma.

If any of the following are unclear:
- text
- icon
- color
- spacing
- state
- button behavior
- validation behavior
- modal/dialog
- animation
- loading UI
- error UI
- success UI
- navigation destination

STOP and ask the user before implementing that part.

Do not redesign the UI without explicit permission.

Only implement the Figma frames specified in the current task.

---

## 6. Reusable Components

Reuse existing components before creating new ones.

Before creating a new component:
1. Search the project for an equivalent component
2. Reuse or extend existing components if appropriate
3. Only create a new component when necessary

Common reusable components may include:
- AppText
- AppTextField
- AppPasswordField
- PrimaryButton
- AppLoading
- AppErrorMessage
- AppHeader
- StatusChip

Do not over-componentize widgets that are only used once.

---

## 7. Design System Rules

Avoid repeated hard-coded styles.

Prefer centralized definitions such as:
- AppColors
- AppTextStyles
- AppSpacing
- AppTheme

Use:
- primary color #1D39C4
- Roboto
- 12px horizontal page margin

Do not create random colors, font sizes, spacing values, or border radii when equivalents already exist.

---

## 8. Bloc Rules

Business state must be managed with Bloc/Cubit.

Do not use setState for feature-level business state.

Typical states may include:
- Initial
- Loading
- Success
- Failure

However:
do not invent new visual states if they are not defined by Figma or requirements.

Bloc/Cubit must not:
- access UI context unnecessarily
- create TextEditingController
- call Dio directly
- depend on concrete mock implementations when abstraction is available

---

## 9. Navigation Rules

Use GoRouter.

Prefer named routes or centralized route constants.

Example:
- AppRoutes.login
- AppRoutes.register
- AppRoutes.forgotPassword

Avoid route strings scattered throughout the project.

Authentication screens must not show BottomNavigationBar.

---

## 10. Form Rules

Use reusable validation where appropriate.

Do not duplicate the same validation logic in multiple screens.

Do not invent business validation rules that are not specified.

Examples of rules that must not be invented:
- password minimum length
- uppercase requirement
- special-character requirement
- OTP length
- phone format specific to business rules

If unclear, ask first.

---

## 11. Security Rules

Never:
- log passwords
- print tokens
- store plain-text passwords
- expose secrets in source code
- hard-code API keys
- commit credentials

Sensitive values should later use secure configuration and secure storage where appropriate.

---

## 12. Clean Code Rules

Follow:
- meaningful variable names
- PascalCase for classes
- snake_case for files
- short focused methods
- const constructors where possible
- avoid duplicate code
- avoid magic numbers
- avoid deeply nested widgets
- keep widgets readable

Do not suppress warnings only to make flutter analyze pass.

Do not over-engineer the project.

Prefer maintainable code suitable for a university graduation project.

---

## 13. Scope Control

Only modify files related to the current task.

Do not:
- refactor unrelated features
- delete working code without explaining why
- change architecture globally without permission
- modify unrelated screens

If a large architecture issue is discovered:
report it first before making broad changes.

---

## 14. Responsive Rules

Figma reference width is 390px.

The UI must still work on common Android screen sizes.

Use when appropriate:
- SafeArea
- Expanded
- Flexible
- SingleChildScrollView
- LayoutBuilder
- MediaQuery

Avoid layouts that cause overflow when keyboard appears.

---

## 15. Dependency Rules

Do not add packages unnecessarily.

Before adding a package:
- check if Flutter SDK or existing package can solve the problem
- explain why the new dependency is needed

Avoid duplicate packages with overlapping responsibilities.

---

## 16. Analysis and Validation

Before coding:
1. Inspect current project structure
2. Check existing components
3. Check existing routes
4. Check existing Bloc/Cubit
5. Check design system
6. Read relevant Figma frames
7. Identify unclear requirements

After coding:
1. Run flutter analyze
2. Fix errors caused by the current implementation
3. Report unrelated existing errors separately
4. Test relevant routes and screens when possible

---

## 17. Required Final Report

After every coding task, report:
- files created
- files modified
- components created
- Bloc/Cubit created
- routes added or changed
- packages added
- assumptions made
- unresolved questions
- known limitations