"""Password hashing.

PBKDF2 from the standard library: no extra dependency to install at a hackathon,
and still a salted, slow hash. Passwords are never stored or logged in plain text —
the database keeps only this string.
"""

import hashlib
import hmac
import secrets

ALGORITHM = "pbkdf2_sha256"
ITERATIONS = 200_000
SALT_BYTES = 16


def hash_password(password: str) -> str:
    """Return "algorithm$iterations$salt$digest" — everything needed to verify."""
    salt = secrets.token_bytes(SALT_BYTES)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, ITERATIONS)
    return f"{ALGORITHM}${ITERATIONS}${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    """Check a password against a stored hash, in constant time."""
    try:
        algorithm, iterations, salt_hex, digest_hex = stored.split("$")
        salt = bytes.fromhex(salt_hex)
        rounds = int(iterations)
    except (ValueError, AttributeError):
        return False

    if algorithm != ALGORITHM:
        return False

    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, rounds)
    return hmac.compare_digest(digest.hex(), digest_hex)
