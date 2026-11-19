// Commit format: type(PascalScope): lowercase message
// Full rules: .github/COMMIT_AND_LINT_GUIDELINES.md
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [
      2,
      "always",
      [
        "feat",
        "fix",
        "refactor",
        "perf",
        "test",
        "docs",
        "style",
        "chore",
        "ci",
        "build",
        "revert",
        "asset", // Roblox builds: maps, models, UI art, sounds
      ],
    ],
    "scope-empty": [2, "never"],
    "scope-case": [2, "always", "pascal-case"],
    "header-max-length": [2, "always", 100],
    "body-max-line-length": [2, "always", 100],
    "footer-max-line-length": [2, "always", 100],
  },
};
