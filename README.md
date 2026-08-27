# Mitigation Action

Mitigation Action runs automated security and risk governance checks on pull requests. It downloads the Mitigation engine, prepares a diff when needed, and generates both a report and a PR comment output.

Learn more at [www.mitigation.team](https://www.mitigation.team).

## Usage

Add the action to a pull request workflow and provide your Mitigation API key:

```yaml
name: Security Governance

on:
  pull_request:

jobs:
  mitigation-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Mitigation
        uses: mitigation-dot-team/action@main
        with:
          api-key: ${{ secrets.MITIGATION_API_KEY }}
```

### Inputs

- `api-key`: Required. Your Mitigation API key.
- `diff-file`: Optional. Path to the `.diff` file to analyze. Defaults to `pr.diff`.
- `version`: Optional. Version of the Mitigation executable to download. Defaults to `latest`.

### Mitigation Plans

Model freemium / pricing plan for licensing and intent-based rate limiting:

|Plan|Price|Included|Modules|
|----|-----|--------|-------|
|Free Tier|0|Up to 100 PR evaluations per month |Basic scanners (WCAG, Secrets), default LLM model (GPT-4o-mini).|
|Pro|USD 49/month per repo|Unlimited evaluations, advanced LLM model (Claude 4.5 Sonnet), auto-fixes in GitHub Suggestions format, Evidence Ledger SHA-256 signing.|Included Free Tier + Security, Compliance modules|
|Enterprise|USD 499/month|Customizable policies, Evidence Ledger storage in your own bucket (S3/GCS), on-premise/self-hosted integration.|All modules|

(*) All plans and price may changes.

[www.mitigation.team](https://www.mitigation.team)
