# Evidence Handling

Store only reviewed, redacted evidence in Git. Raw CLI output, logs, JSON exports, and screenshots belong in ignored subdirectories until they have been checked for account IDs, ARNs, IP addresses, email addresses, secret values, session identifiers, and other sensitive data.

Experiment narratives belong in `docs/experiments/` and should link to sanitized artifacts only.
