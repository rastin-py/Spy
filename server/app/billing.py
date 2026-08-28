"""Receipt verification, and the seam the real store APIs plug into.

**Not yet wired to Bazaar or Myket.** Both want an OAuth client and a refresh
token issued from the developer console, which is a thing to configure rather
than a thing to write. Until they are set, `verify` records the receipt as
`pending` and the app treats pending as entitled.

That default is deliberate. There are two ways to be wrong about a receipt:
show adverts to somebody who paid, or hide them from somebody who did not. The
first costs a person money and a review; the second costs a fraction of a
rial. It is not a close call, and it stays this way even after the real
verifiers land - a store we cannot reach means pending, never invalid.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

log = logging.getLogger("spy.billing")


@dataclass(frozen=True, slots=True)
class Verdict:
    state: str  # valid | pending | invalid | refunded
    raw: str | None = None


class StoreVerifier:
    """One per store. Implementations go alongside this class."""

    name = "none"

    def verify(self, product_id: str, token: str) -> Verdict:
        raise NotImplementedError


class UnconfiguredVerifier(StoreVerifier):
    """Records the receipt and gets on with it.

    What a real one will do instead:

    * **Bazaar** - `GET https://pardakht.cafebazaar.ir/devapi/v2/api/validate/
      {package}/inapp/{product_id}/purchases/{token}/` with an OAuth bearer
      token refreshed from the console's client id and secret. A 200 with
      `consumptionState`/`purchaseState` is the answer.
    * **Myket** - the equivalent developer API, same shape of exchange.

    Both need credentials in the environment, which is why this is a seam and
    not a stub full of guesses.
    """

    def __init__(self, name: str) -> None:
        self.name = name

    def verify(self, product_id: str, token: str) -> Verdict:
        log.info(
            "receipt recorded, not verified - no store credentials configured",
            extra={"store": self.name, "product": product_id},
        )
        return Verdict("pending")


_verifiers: dict[str, StoreVerifier] = {}


def verifier_for(store: str) -> StoreVerifier:
    if store not in _verifiers:
        _verifiers[store] = UnconfiguredVerifier(store)
    return _verifiers[store]


def register(store: str, verifier: StoreVerifier) -> None:
    """Called at startup once a store's credentials exist."""
    _verifiers[store] = verifier
    log.info("store verifier registered", extra={"store": store})
