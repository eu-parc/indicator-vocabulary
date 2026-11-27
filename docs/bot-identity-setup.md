# Setting Up the Publishing Bot Identity

The defining nanopublications are signed and published by a bot: a software
agent with its own RSA keypair. The bot is introduced once by an introduction
nanopublication that binds the agent URI to its public key.

Defaults are defined in the `Makefile`:

| Variable | Default |
|---|---|
| `BOT_NAME` | `Indicator bot` |
| `BOT_ID` | `indicator-bot` |
| `BOT_OWNER_ORCID`, `BOT_OWNER_NAME` | none: the ORCID and name of the person who sets up the bot (the current Indicator bot's introduction names Gertjan Bisschop) |
| `CI_REPO` | `eu-parc/indicator-vocabulary` |

## Steps

```bash
make bot-identity
make publish-bot-introduction
make bot-ci-secrets
```

Review `bot-identity/introduction.trig` before publishing. The private key is
the bot identity and must stay out of git; `bot-identity/` is ignored.
