# McNemar Test

Compares two binary measurements taken on the same subjects, for example before and after a treatment. Only the discordant pairs (subjects who changed category) carry information.

- The chi-square version uses a continuity correction by default.
- With fewer than about 25 discordant pairs, use the **exact** binomial test.

Both variables must use the same two categories.

R functions: `mcnemar.test()`, `binom.test()`.
