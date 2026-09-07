# Voceive Demo Dataset

Realistic SaaS customer-support conversations for demonstrating the Voceive intelligence pipeline.

## Dataset

`atlas_demo_customers.csv` — 150 customer conversations with realistic variation in:

- Sentiment (positive, neutral, negative, mixed)
- Categories (billing, auth, bugs, features, integrations, etc.)
- Signal overlap (bug + negative, feature request + positive, etc.)
- Ambiguity (~15% deliberately ambiguous)
- Language style (short/long, polite/frustrated, grammatical/informal)

## Import

Upload via the Voceive UI or API:

```bash
# Via API (requires a valid JWT token and organization)
curl -X POST http://localhost:3000/api/v1/uploads \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@scripts/demo/atlas_demo_customers.csv"
```

Or use the web UI: navigate to Import → Upload CSV → select this file.

The standard Voceive pipeline will process all tickets:
1. `Tickets::ProcessCsv` creates ticket records
2. `AnalyzeTicketJob` enqueues AI analysis for each ticket
3. AI analysis populates sentiment, categories, and signals
4. Executive summary can be generated from the Reports page

## Reset

To re-import, delete existing tickets (via Rails console or fresh DB) and re-upload:

```bash
cd apps/api
bundle exec rails runner "Ticket.destroy_all; Upload.destroy_all; AiAnalysis.destroy_all"
```

Then re-upload the CSV.

## Notes

- All customer data is fictional (no real PII)
- Email domains use `example.com`
- Companies are fictional (Northstar Labs, Acme Retail, BrightPath, etc.)
- Dataset is deterministic and version-controlled
