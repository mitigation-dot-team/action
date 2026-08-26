Usage:
```
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
        uses: mitigation-dot-team/mitigation-action@v1.6.0
        with:
          api-key: ${{ secrets.MITIGATION_API_KEY }}
```
